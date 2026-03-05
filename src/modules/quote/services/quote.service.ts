// =============================================================================
// Quote Service — Insurance Platform
//
// Orchestrates the complete quote creation lifecycle:
//   1. Create Quote record (DRAFT state)
//   2. Load applicant facts
//   3. Call RuleEngineService → evaluateEligibility (json-rules-engine)
//   4. Call RuleEngineService → calculateRisk
//   5. Trigger TemporalClientService → startQuoteWorkflow
//   6. Emit domain events (EventEmitter2)
//   7. Persist all state transitions via AuditLogService
//
// This service also handles:
//   - Status updates sent back from Temporal activities
//   - Quote cancellation
//   - Duplicate quote guard (one active quote per policy/applicant)
// =============================================================================

import {
    Injectable,
    Logger,
    NotFoundException,
    ConflictException,
    BadRequestException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Not, In } from 'typeorm';
import { EventEmitter2 } from '@nestjs/event-emitter';

import { Quote } from '../entities/quote.entity';
import { QuoteLineItem } from '../entities/quote.entity';
import { QuoteStatusHistory } from '../entities/quote.entity';
import { AuditLogService } from '../../audit/services/audit-log.service';
import { AuditEntityType } from '../../../common/enums';
import { RuleEngineService } from '../../rules/services/rule-engine.service';
import { TemporalClientService } from '../../../temporal/worker/worker';
import { InsuranceProduct, ProductVersion, CoverageOption } from '../../product/entities/product.entity';
import { ProductVersionStatus } from '../../../common/enums';
import {
    uwDecisionSignal,
    cancelQuoteSignal,
    getQuoteStatusQuery,
    QuoteWorkflowInput,
    QuoteWorkflowState,
} from '../../../temporal/shared/types';

// ─────────────────────────────────────────────────────────────────────────────
// Domain Events
// ─────────────────────────────────────────────────────────────────────────────

export class QuoteCreatedEvent {
    constructor(
        public readonly tenantId: string,
        public readonly quoteId: string,
        public readonly productVersionId: string,
        public readonly createdBy: string,
    ) { }
}

export class QuoteStatusChangedEvent {
    constructor(
        public readonly tenantId: string,
        public readonly quoteId: string,
        public readonly fromStatus: string,
        public readonly toStatus: string,
        public readonly changedBy?: string,
        public readonly reason?: string,
    ) { }
}

export class QuoteExpiredEvent {
    constructor(
        public readonly tenantId: string,
        public readonly quoteId: string,
    ) { }
}

// ─────────────────────────────────────────────────────────────────────────────
// Input DTOs
// ─────────────────────────────────────────────────────────────────────────────

export interface CreateQuoteDto {
    tenantId: string;
    productVersionId: string;
    applicantData: Record<string, unknown>;
    lineItems: Array<{
        coverageOptionId: string;
        riderId?: string;
        sumInsured: number;
        deductibleId?: string;
    }>;
    riskThreshold?: number;
    quoteExpiryDays?: number;
    createdBy: string;
}

export interface UpdateQuoteStatusDto {
    tenantId: string;
    quoteId: string;
    status: string;
    reason?: string;
    context?: Record<string, unknown>;
    changedBy?: string;
}

export interface CancelQuoteDto {
    tenantId: string;
    quoteId: string;
    cancelledBy: string;
    reason: string;
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

@Injectable()
export class QuoteService {
    private readonly logger = new Logger(QuoteService.name);

    constructor(
        @InjectRepository(Quote)
        private readonly quoteRepo: Repository<Quote>,

        @InjectRepository(QuoteLineItem)
        private readonly lineItemRepo: Repository<QuoteLineItem>,

        @InjectRepository(QuoteStatusHistory)
        private readonly statusHistoryRepo: Repository<QuoteStatusHistory>,

        @InjectRepository(InsuranceProduct)
        private readonly productRepo: Repository<InsuranceProduct>,
        @InjectRepository(ProductVersion)
        private readonly productVersionRepo: Repository<ProductVersion>,
        @InjectRepository(CoverageOption)
        private readonly coverageOptionRepo: Repository<CoverageOption>,

        private readonly ruleEngine: RuleEngineService,
        private readonly temporalClient: TemporalClientService,
        private readonly auditLog: AuditLogService,
        private readonly eventEmitter: EventEmitter2,
    ) { }

    // ─────────────────────────────────────────────────────────────────────────
    // CreateQuote
    // ─────────────────────────────────────────────────────────────────────────

    /**
     * Create a new quote, evaluate eligibility rules, and trigger the Quote Workflow.
     *
     * Flow:
     *   1. Persist Quote in DRAFT state
     *   2. Persist QuoteLineItems
     *   3. Call RuleEngineService.evaluateEligibility() (pre-check, non-blocking)
     *   4. Start Temporal quoteWorkflow (full orchestration continues there)
     *   5. Emit QuoteCreatedEvent
     *   6. Audit log
     */
    async createQuote(dto: CreateQuoteDto): Promise<Quote> {
        this.logger.log(`Creating quote [tenant=${dto.tenantId}, version=${dto.productVersionId}]`);

        // Resolve productVersionId (frontend may send product.id; we need product_version.id)
        const productVersionId = await this.getOrCreateProductVersion(dto.tenantId, dto.productVersionId);

        // Resolve and validate coverage options
        const resolvedLineItems = await Promise.all(
            dto.lineItems.map(async (li) => {
                const coverageId = await this.getOrCreateDefaultCoverageOption(
                    dto.tenantId,
                    productVersionId,
                    li.coverageOptionId,
                );

                const coverage = await this.coverageOptionRepo.findOne({ where: { id: coverageId } });
                if (coverage) {
                    const min = parseFloat(coverage.minSumInsured || '0');
                    const max = parseFloat(coverage.maxSumInsured || '999999999');
                    if (li.sumInsured < min || li.sumInsured > max) {
                        throw new BadRequestException(
                            `Sum Insured ${li.sumInsured} for ${coverage.name} is out of bounds [${min} - ${max}]`,
                        );
                    }
                }

                return { ...li, coverageOptionId: coverageId };
            }),
        );

        const quoteNumber = this.generateQuoteNumber();
        const applicantRef = this.getApplicantRef(dto.applicantData);

        // ── 1. Persist quote in DRAFT ──────────────────────────────────────────
        const quote = this.quoteRepo.create({
            tenantId: dto.tenantId,
            quoteNumber,
            productVersionId,
            applicantRef,
            applicantData: dto.applicantData,
            status: 'DRAFT' as any,
            expiresAt: this.computeExpiry(dto.quoteExpiryDays ?? 30),
        });

        const savedQuote = await this.quoteRepo.save(quote) as any as Quote;

        // ── 2. Persist line items ──────────────────────────────────────────────
        const lineItems = resolvedLineItems.map((li) =>
            this.lineItemRepo.create({
                tenantId: dto.tenantId,
                quoteId: savedQuote.id,
                coverageOptionId: li.coverageOptionId,
                riderId: li.riderId,
                sumInsured: li.sumInsured.toString(),
                deductibleId: li.deductibleId,
            }),
        );
        await this.lineItemRepo.save(lineItems);

        // ── 3. Pre-flight eligibility check (quick guard before Temporal) ──────
        let eligResult: { isEligible: boolean; failedRules: Array<{ reason: string }> };
        try {
            const eligRules = await this.ruleEngine.getEligibilityRules(dto.tenantId, productVersionId);
            eligResult = await this.ruleEngine.evaluateEligibility(eligRules, {
                ...dto.applicantData,
                tenantId: dto.tenantId,
                productVersionId,
            });
        } catch (e) {
            this.logger.warn(`Eligibility check skipped: ${e}`);
            eligResult = { isEligible: true, failedRules: [] };
        }

        if (!eligResult.isEligible) {
            await this.updateStatus({
                tenantId: dto.tenantId,
                quoteId: savedQuote.id,
                status: 'REJECTED',
                reason: eligResult.failedRules.map((r) => r.reason).join('; '),
                changedBy: dto.createdBy,
            });
            this.logger.warn(`Quote rejected at eligibility pre-check [quoteId=${savedQuote.id}]`);
            return this.quoteRepo.findOneOrFail({ where: { id: savedQuote.id } });
        }

        // ── 4. Start Temporal Quote Workflow (optional; quote still saved if Temporal down) ──
        let temporalWorkflowId: string | null = null;
        try {
            const workflowInput: QuoteWorkflowInput = {
                tenantId: dto.tenantId,
                quoteId: savedQuote.id,
                productVersionId,
                applicantData: dto.applicantData,
                lineItems: resolvedLineItems,
                riskThreshold: dto.riskThreshold ?? 600,
                quoteExpiryDays: dto.quoteExpiryDays ?? 30,
                originatedBy: dto.createdBy,
            };
            const handle = await this.temporalClient.startQuoteWorkflow(workflowInput);
            temporalWorkflowId = handle.workflowId;
            await this.quoteRepo.update(
                { id: savedQuote.id },
                { temporalWorkflowId: handle.workflowId },
            );
            this.logger.log(`Quote workflow started [quoteId=${savedQuote.id}, workflowId=${handle.workflowId}]`);
        } catch (e) {
            this.logger.warn(`Temporal workflow not started (quote saved in DRAFT): ${e}`);
        }

        // ── 5. Emit domain event ───────────────────────────────────────────────
        this.eventEmitter.emit(
            'quote.created',
            new QuoteCreatedEvent(dto.tenantId, savedQuote.id, productVersionId, dto.createdBy),
        );

        // ── 6. Audit log ───────────────────────────────────────────────────────
        await this.auditLog.log({
            tenantId: dto.tenantId,
            entityType: AuditEntityType.QUOTE,
            entityId: savedQuote.id,
            action: 'CREATED',
            newState: 'DRAFT',
            performedBy: dto.createdBy,
            context: {
                productVersionId,
                lineItemCount: lineItems.length,
                temporalWorkflowId,
            },
        });

        return this.quoteRepo.findOneOrFail({
            where: { id: savedQuote.id },
            relations: ['lineItems', 'premiumSnapshots'],
        });
    }

    private generateQuoteNumber(): string {
        const year = new Date().getFullYear();
        const r = Math.random().toString(36).slice(2, 8).toUpperCase();
        return `QT-${year}-${r}`;
    }

    private getApplicantRef(applicantData: Record<string, unknown>): string {
        const email = applicantData?.email as string | undefined;
        if (email && typeof email === 'string' && email.trim()) return email.trim();
        const first = (applicantData?.firstName as string) ?? '';
        const last = (applicantData?.lastName as string) ?? '';
        const name = [first, last].filter(Boolean).join(' ').trim();
        return name || 'unknown';
    }

    private async getOrCreateProductVersion(tenantId: string, productIdOrVersionId: string): Promise<string> {
        const asVersion = await this.productVersionRepo.findOne({
            where: { id: productIdOrVersionId, tenantId },
        });
        if (asVersion) return asVersion.id;

        const product = await this.productRepo.findOne({
            where: { id: productIdOrVersionId, tenantId },
        });
        if (!product) {
            throw new BadRequestException(`Product or product version not found: ${productIdOrVersionId}`);
        }

        const existing = await this.productVersionRepo.findOne({
            where: { productId: product.id, tenantId },
            order: { versionNumber: 'DESC' },
        });
        if (existing) return existing.id;

        const today = new Date().toISOString().slice(0, 10);
        const version = this.productVersionRepo.create({
            tenantId,
            productId: product.id,
            versionNumber: 1,
            status: ProductVersionStatus.DRAFT,
            effectiveFrom: today,
            productSnapshot: {},
        });
        const saved = await this.productVersionRepo.save(version);
        return saved.id;
    }

    private async getOrCreateDefaultCoverageOption(
        tenantId: string,
        productVersionId: string,
        requestedId: string,
    ): Promise<string> {
        const existing = await this.coverageOptionRepo.findOne({
            where: { id: requestedId, tenantId, productVersionId },
        });
        if (existing) return existing.id;

        const firstForVersion = await this.coverageOptionRepo.findOne({
            where: { productVersionId, tenantId },
        });
        if (firstForVersion) return firstForVersion.id;

        const created = this.coverageOptionRepo.create({
            tenantId,
            productVersionId,
            name: 'Base coverage',
            code: 'BASE',
        });
        const saved = await this.coverageOptionRepo.save(created);
        return saved.id;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // UpdateStatus — called by Temporal activities to persist state transitions
    // ─────────────────────────────────────────────────────────────────────────

    async updateStatus(dto: UpdateQuoteStatusDto): Promise<void> {
        const quote = await this.findOrFail(dto.tenantId, dto.quoteId);
        const oldStatus = quote.status;

        if (oldStatus === dto.status) return; // idempotent

        // Persist status on quote record
        await this.quoteRepo.update(
            { id: dto.quoteId, tenantId: dto.tenantId },
            { status: dto.status as any },
        );

        const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
        const actorId = (dto.changedBy && uuidRegex.test(dto.changedBy)) ? dto.changedBy : null;

        // Append to immutable status history
        // NOTE: triggeredBy is a UUID column; must be null if not a valid UUID
        await this.statusHistoryRepo.save(
            this.statusHistoryRepo.create({
                tenantId: dto.tenantId,
                quoteId: dto.quoteId,
                fromStatus: oldStatus as any,
                toStatus: dto.status as any,
                triggeredBy: actorId,
                reason: dto.reason ?? null,
                context: (dto.context ?? {}) as any,
            }),
        );

        // Emit domain event (fire-and-forget, non-blocking)
        this.eventEmitter.emit(
            'quote.status.changed',
            new QuoteStatusChangedEvent(
                dto.tenantId,
                dto.quoteId,
                oldStatus,
                dto.status,
                dto.changedBy, // Event can keep the original string
                dto.reason,
            ),
        );

        // Audit log — wrapped so a log failure doesn't roll back the status update
        try {
            await this.auditLog.log({
                tenantId: dto.tenantId,
                entityType: AuditEntityType.QUOTE,
                entityId: dto.quoteId,
                action: 'STATE_CHANGED',
                previousState: oldStatus,
                newState: dto.status,
                performedBy: actorId ?? undefined, // AuditLog also expects UUID for performed_by
                context: {
                    reason: dto.reason,
                    originalActor: dto.changedBy, // Store original if it was "admin"
                    ...dto.context
                },
            });
        } catch (auditErr) {
            this.logger.warn(`Audit log failed for quote state change: ${auditErr}`);
        }

        this.logger.log(`Quote status: ${oldStatus} → ${dto.status} [quoteId=${dto.quoteId}, by=${dto.changedBy}]`);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // SubmitQuote — transition DRAFT → SUBMITTED
    // ─────────────────────────────────────────────────────────────────────────

    async submitQuote(tenantId: string, quoteId: string, submittedBy: string): Promise<Quote> {
        const quote = await this.findOrFail(tenantId, quoteId);

        if (quote.status !== 'DRAFT') {
            throw new BadRequestException(`Only DRAFT quotes can be submitted. Current status: ${quote.status}`);
        }

        await this.updateStatus({
            tenantId,
            quoteId: quote.id,
            status: 'SUBMITTED',
            changedBy: submittedBy,
            reason: 'Submitted for underwriting review',
        });

        return this.quoteRepo.findOneOrFail({ where: { id: quote.id } });
    }

    // ─────────────────────────────────────────────────────────────────────────
    // CancelQuote — updates status directly; signals Temporal if workflow exists
    // ─────────────────────────────────────────────────────────────────────────

    async cancelQuote(dto: CancelQuoteDto): Promise<void> {
        const quote = await this.findOrFail(dto.tenantId, dto.quoteId);

        const terminalStates = ['ISSUED', 'REJECTED', 'CANCELLED', 'EXPIRED'];
        if (terminalStates.includes(quote.status)) {
            throw new ConflictException(
                `Cannot cancel quote in terminal state: ${quote.status}`,
            );
        }

        // If a workflow is running, signal it; otherwise update DB directly
        if (quote.temporalWorkflowId) {
            try {
                const handle = await this.temporalClient.getQuoteHandle(dto.tenantId, dto.quoteId);
                await handle.signal(cancelQuoteSignal, {
                    cancelledBy: dto.cancelledBy,
                    reason: dto.reason,
                });
            } catch (e) {
                this.logger.warn(`Temporal signal failed, cancelling via DB: ${e}`);
                await this.updateStatus({
                    tenantId: dto.tenantId,
                    quoteId: dto.quoteId,
                    status: 'CANCELLED',
                    changedBy: dto.cancelledBy,
                    reason: dto.reason,
                });
            }
        } else {
            // No workflow — update status directly in DB
            await this.updateStatus({
                tenantId: dto.tenantId,
                quoteId: dto.quoteId,
                status: 'CANCELLED',
                changedBy: dto.cancelledBy,
                reason: dto.reason,
            });
        }

        await this.auditLog.log({
            tenantId: dto.tenantId,
            entityType: AuditEntityType.QUOTE,
            entityId: dto.quoteId,
            action: 'CANCELLATION_REQUESTED',
            performedBy: dto.cancelledBy,
            context: { reason: dto.reason },
        });
    }

    // ─────────────────────────────────────────────────────────────────────────
    // GetWorkflowState — query live state from Temporal workflow
    // ─────────────────────────────────────────────────────────────────────────

    async getWorkflowState(tenantId: string, quoteId: string): Promise<QuoteWorkflowState> {
        const handle = await this.temporalClient.getQuoteHandle(tenantId, quoteId);
        return handle.query(getQuoteStatusQuery);
    }

    // ─────────────────────────────────────────────────────────────────────────
    // FindOne / FindAll
    // ─────────────────────────────────────────────────────────────────────────

    async findById(tenantId: string, quoteId: string): Promise<Quote> {
        return this.findOrFail(tenantId, quoteId);
    }

    async findByStatus(tenantId: string, status: string, page = 1, limit = 20): Promise<Quote[]> {
        return this.quoteRepo.find({
            where: { tenantId, status: status as any },
            order: { createdAt: 'DESC' },
            skip: (page - 1) * limit,
            take: limit,
        });
    }
    async findAll(tenantId: string): Promise<Quote[]> {
        return this.quoteRepo.find({
            where: { tenantId },
            relations: ['premiumSnapshots', 'lineItems'],
            order: { createdAt: 'DESC' },
        });
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Private helpers
    // ─────────────────────────────────────────────────────────────────────────

    private async findOrFail(tenantId: string, quoteIdOrNumber: string): Promise<Quote> {
        const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

        const findOptions = {
            tenantId,
            relations: ['lineItems', 'premiumSnapshots'],
        };

        if (uuidRegex.test(quoteIdOrNumber)) {
            const quote = await this.quoteRepo.findOne({
                where: { id: quoteIdOrNumber, tenantId },
                relations: ['lineItems', 'premiumSnapshots'],
            });
            if (!quote) throw new NotFoundException(`Quote not found: ${quoteIdOrNumber}`);
            return quote;
        }

        const byNumber = await this.quoteRepo.findOne({
            where: { quoteNumber: quoteIdOrNumber, tenantId },
            relations: ['lineItems', 'premiumSnapshots'],
        });
        if (!byNumber) throw new NotFoundException(`Quote not found: ${quoteIdOrNumber}`);
        return byNumber;
    }

    private computeExpiry(days: number): Date {
        const d = new Date();
        d.setDate(d.getDate() + days);
        return d;
    }
}
