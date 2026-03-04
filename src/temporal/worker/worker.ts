// =============================================================================
// Temporal Worker — Insurance Platform
//
// NestJS-integrated Temporal worker that registers:
//   - Quote Workflow + all quote activities
//   - Claim Workflow + all claim activities
//
// Architecture:
//   - NestJS services are injected at startup into activity factories
//   - Worker runs in the same process as NestJS (or a separate worker process)
//   - Two task queues: QUOTE_TASK_QUEUE and CLAIM_TASK_QUEUE
//     (separate queues allow independent scaling of worker pools)
//
// Startup:
//   Called from main.ts via WorkerBootstrapService.onApplicationBootstrap()
//
// Shutdown:
//   Graceful shutdown via NestJS lifecycle hooks — worker.shutdown() flushes
//   in-flight activities before process exit.
// =============================================================================

import { NativeConnection, Worker, Runtime, DefaultLogger, LogLevel } from '@temporalio/worker';
import { Injectable, OnApplicationBootstrap, OnApplicationShutdown, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ModuleRef } from '@nestjs/core';

import { quoteWorkflow } from '../workflows/quote.workflow';
import { claimWorkflow } from '../workflows/claim.workflow';
import { createQuoteActivities } from '../activities/quote.activities';
import { createClaimActivities } from '../activities/claim.activities';

// Task queue identifiers — also used by NestJS services to start workflows
export const QUOTE_TASK_QUEUE = 'insurance.quote.queue';
export const CLAIM_TASK_QUEUE = 'insurance.claim.queue';

// ─────────────────────────────────────────────────────────────────────────────
// WorkerBootstrapService
//
// NestJS Injectable that creates and manages both workers.
// Inject NestJS services here so activities can call the application layer.
// ─────────────────────────────────────────────────────────────────────────────
@Injectable()
export class TemporalWorkerService implements OnApplicationBootstrap, OnApplicationShutdown {
    private readonly logger = new Logger(TemporalWorkerService.name);
    private quoteWorker: Worker | null = null;
    private claimWorker: Worker | null = null;

    constructor(
        private readonly configService: ConfigService,
        private readonly moduleRef: ModuleRef,
    ) { }

    async onApplicationBootstrap(): Promise<void> {
        const enabled = this.configService.get<string>('TEMPORAL_ENABLED', 'true');
        if (enabled === 'false' || enabled === '0') {
            this.logger.warn('Temporal is disabled (TEMPORAL_ENABLED=false). API will run without workflows. Start Temporal for full functionality.');
            return;
        }

        const temporalAddress = this.configService.get<string>('TEMPORAL_ADDRESS', 'localhost:7233');
        const temporalNamespace = this.configService.get<string>('TEMPORAL_NAMESPACE', 'default');

        try {
            // ── Configure Runtime Logger ─────────────────────────────────────────
            Runtime.install({
                logger: new DefaultLogger(
                    this.configService.get<string>('NODE_ENV') === 'production' ? 'WARN' : 'INFO',
                ),
            });

            // ── Shared Temporal Connection ───────────────────────────────────────
            const connection = await NativeConnection.connect({
                address: temporalAddress,
            });

            this.logger.log(`Connected to Temporal at ${temporalAddress} (namespace: ${temporalNamespace})`);

            // ── Lazy-resolve NestJS services ─────────────────────────────────────
            const quoteService = this.moduleRef.get('QuoteService', { strict: false });
            const riskService = this.moduleRef.get('RiskService', { strict: false });
            const ruleEngine = this.moduleRef.get('RuleEngineService', { strict: false });
            const premiumService = this.moduleRef.get('PremiumService', { strict: false });
            const uwService = this.moduleRef.get('UnderwritingService', { strict: false });
            const policyService = this.moduleRef.get('PolicyService', { strict: false });
            const notificationSvc = this.moduleRef.get('NotificationService', { strict: false });
            const auditService = this.moduleRef.get('AuditService', { strict: false });
            const claimService = this.moduleRef.get('ClaimService', { strict: false });
            const claimPolicyService = this.moduleRef.get('ClaimPolicyService', { strict: false });
            const fraudService = this.moduleRef.get('FraudService', { strict: false });
            const financeService = this.moduleRef.get('FinanceService', { strict: false });

            const quoteActivities = createQuoteActivities({
                quoteService,
                riskService,
                ruleEngine,
                premiumService,
                uwService,
                policyService,
                notificationService: notificationSvc,
                auditService,
            });

            const claimActivities = createClaimActivities({
                claimService,
                policyService: claimPolicyService,
                ruleEngine,
                fraudService,
                financeService,
                notificationService: notificationSvc,
                auditService,
            });

            this.quoteWorker = await Worker.create({
                connection,
                namespace: temporalNamespace,
                taskQueue: QUOTE_TASK_QUEUE,
                workflowsPath: require.resolve('../workflows/quote.workflow'),
                activities: quoteActivities,
                maxConcurrentActivityTaskExecutions: 200,
                maxConcurrentWorkflowTaskExecutions: 200,
                maxCachedWorkflows: 2000,
            });

            this.claimWorker = await Worker.create({
                connection,
                namespace: temporalNamespace,
                taskQueue: CLAIM_TASK_QUEUE,
                workflowsPath: require.resolve('../workflows/claim.workflow'),
                activities: claimActivities,
                maxConcurrentActivityTaskExecutions: 200,
                maxConcurrentWorkflowTaskExecutions: 200,
                maxCachedWorkflows: 2000,
            });

            this.logger.log(`Quote Worker registered on queue: ${QUOTE_TASK_QUEUE}`);
            this.logger.log(`Claim Worker registered on queue: ${CLAIM_TASK_QUEUE}`);

            // Start workers (non-blocking — runs in background)
            this.startWorkers();
        } catch (err: any) {
            this.logger.warn(
                `Temporal unavailable (${err?.message ?? err}). Running without workflows. ` +
                'To enable: start Temporal (e.g. docker compose -f docker-compose.temporal.yml up -d) and set TEMPORAL_ADDRESS if needed.',
            );
        }
    }

    private startWorkers(): void {
        // run() returns a Promise that resolves when the worker is shut down.
        // We intentionally do NOT await — workers run for the lifetime of the process.
        this.quoteWorker?.run().catch((err) => {
            this.logger.error('Quote Worker crashed', err);
        });

        this.claimWorker?.run().catch((err) => {
            this.logger.error('Claim Worker crashed', err);
        });
    }

    async onApplicationShutdown(signal?: string): Promise<void> {
        if (!this.quoteWorker && !this.claimWorker) return;
        this.logger.log(`Shutting down Temporal workers (signal: ${signal})`);
        await Promise.allSettled([
            this.quoteWorker?.shutdown(),
            this.claimWorker?.shutdown(),
        ]);
        this.logger.log('Temporal workers shut down cleanly');
    }
}

// =============================================================================
// TemporalClientService — for starting workflows from NestJS services
// =============================================================================

import { Client, Connection, WorkflowHandle, WorkflowIdReusePolicy } from '@temporalio/client';
import { QuoteWorkflowInput, ClaimWorkflowInput } from '../shared/types';
import { quoteWorkflow as quoteWf } from '../workflows/quote.workflow';
import { claimWorkflow as claimWf } from '../workflows/claim.workflow';

@Injectable()
export class TemporalClientService {
    private client: Client | null = null;
    private readonly logger = new Logger(TemporalClientService.name);

    constructor(private readonly configService: ConfigService) { }

    async getClient(): Promise<Client> {
        if (!this.client) {
            const connection = await Connection.connect({
                address: this.configService.get<string>('TEMPORAL_ADDRESS', 'localhost:7233'),
            });
            this.client = new Client({
                connection,
                namespace: this.configService.get<string>('TEMPORAL_NAMESPACE', 'default'),
            });
        }
        return this.client;
    }

    // ── Start Quote Workflow ─────────────────────────────────────────────────
    async startQuoteWorkflow(
        input: QuoteWorkflowInput,
    ): Promise<WorkflowHandle<typeof quoteWf>> {
        const client = await this.getClient();
        const workflowId = `quote:${input.tenantId}:${input.quoteId}`;

        this.logger.log(`Starting quote workflow: ${workflowId}`);

        return client.workflow.start(quoteWf, {
            taskQueue: QUOTE_TASK_QUEUE,
            workflowId,
            args: [input],
            // Prevent duplicate workflow starts (idempotent)
            workflowIdReusePolicy: WorkflowIdReusePolicy.WORKFLOW_ID_REUSE_POLICY_REJECT_DUPLICATE,
            // Quote expiry also enforced in workflow via sleep(); this is a hard cap
            workflowExecutionTimeout: `${input.quoteExpiryDays}d`,
        });
    }

    // ── Start Claim Workflow ─────────────────────────────────────────────────
    async startClaimWorkflow(
        input: ClaimWorkflowInput,
    ): Promise<WorkflowHandle<typeof claimWf>> {
        const client = await this.getClient();
        const workflowId = `claim:${input.tenantId}:${input.claimId}`;

        this.logger.log(`Starting claim workflow: ${workflowId}`);

        return client.workflow.start(claimWf, {
            taskQueue: CLAIM_TASK_QUEUE,
            workflowId,
            args: [input],
            workflowIdReusePolicy: WorkflowIdReusePolicy.WORKFLOW_ID_REUSE_POLICY_REJECT_DUPLICATE,
            workflowExecutionTimeout: '365d',  // claims can be open for up to 1 year
        });
    }

    // ── Get Workflow Handle (for signal / query) ─────────────────────────────
    async getQuoteHandle(
        tenantId: string,
        quoteId: string,
    ): Promise<WorkflowHandle<typeof quoteWf>> {
        const client = await this.getClient();
        return client.workflow.getHandle<typeof quoteWf>(`quote:${tenantId}:${quoteId}`);
    }

    async getClaimHandle(
        tenantId: string,
        claimId: string,
    ): Promise<WorkflowHandle<typeof claimWf>> {
        const client = await this.getClient();
        return client.workflow.getHandle<typeof claimWf>(`claim:${tenantId}:${claimId}`);
    }
}

// =============================================================================
// NestJS Module Registration
// =============================================================================

import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';

@Module({
    imports: [ConfigModule],
    providers: [TemporalWorkerService, TemporalClientService],
    exports: [TemporalClientService],
})
export class TemporalModule { }
