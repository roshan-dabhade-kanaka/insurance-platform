import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Between } from 'typeorm';
import { Claim } from '../claim/entities/claim.entity';
import { PayoutRequest } from '../finance/entities/finance.entity';
import { Quote } from '../quote/entities/quote.entity';
import { AuditLog } from '../audit/entities/audit-log.entity';
import { Policy } from '../policy/entities/policy.entity';
import { InsuranceProduct, ProductVersion } from '../product/entities/product.entity';
import { User } from '../iam/entities/user.entity';
import * as ExcelJS from 'exceljs';
import * as PDFDocument from 'pdfkit';

@Injectable()
export class ReportingService {
    private readonly logger = new Logger(ReportingService.name);

    constructor(
        @InjectRepository(Quote)
        private readonly quoteRepo: Repository<Quote>,
        @InjectRepository(Claim)
        private readonly claimRepo: Repository<Claim>,
        @InjectRepository(PayoutRequest)
        private readonly payoutRepo: Repository<PayoutRequest>,
        @InjectRepository(AuditLog)
        private readonly auditRepo: Repository<AuditLog>,
        @InjectRepository(Policy)
        private readonly policyRepo: Repository<Policy>,
        @InjectRepository(User)
        private readonly userRepo: Repository<User>,
    ) { }

    async generateSummary(tenantId: string, type: string, fromDate?: string, toDate?: string) {
        this.logger.log(`Generating report ${type} for tenant ${tenantId}`);

        const start = fromDate ? new Date(fromDate) : new Date(0);
        let end = toDate ? new Date(toDate) : new Date();
        if (toDate) end.setUTCHours(23, 59, 59, 999);

        const dateRange = Between(start, end);

        switch (type) {
            case 'PREMIUM_SUMMARY':
                const quotes = await this.quoteRepo.find({
                    where: { tenantId, status: 'ISSUED' as any, createdAt: dateRange },
                    relations: ['premiumSnapshots'],
                });

                let revenue = 0;
                for (const q of quotes) {
                    if (q.premiumSnapshots?.length) {
                        const latest = [...q.premiumSnapshots].sort(
                            (a, b) => b.calculatedAt.getTime() - a.calculatedAt.getTime(),
                        )[0];
                        revenue += parseFloat(latest.totalPremium || '0');
                    }
                }

                return {
                    totalRevenue: revenue,
                    issuedQuotesCount: quotes.length,
                    reportType: 'Premium Summary',
                };

            case 'CLAIMS_BY_PRODUCT':
                const query = this.claimRepo
                    .createQueryBuilder('claim')
                    .leftJoin(Policy, 'policy', 'policy.id = claim.policyId')
                    .leftJoin(ProductVersion, 'pv', 'pv.id = policy.productVersionId')
                    .leftJoin(InsuranceProduct, 'prod', 'prod.id = pv.productId')
                    .select([
                        'claim.id as id',
                        'claim.claimedAmount as amount',
                        'prod.name as productName',
                    ])
                    .where('claim.tenantId = :tenantId', { tenantId })
                    .andWhere('claim.createdAt BETWEEN :start AND :end', {
                        start,
                        end,
                    });

                const claimsWithProduct = await query.getRawMany();
                const productBreakdown: any = {};
                let totalValue = 0;

                claimsWithProduct.forEach((row) => {
                    const name = row.productName || 'Generic Policy';
                    const amt = parseFloat(row.amount || '0');
                    totalValue += amt;
                    if (!productBreakdown[name])
                        productBreakdown[name] = { count: 0, totalAmount: 0 };
                    productBreakdown[name].count++;
                    productBreakdown[name].totalAmount += amt;
                });

                return {
                    totalClaims: claimsWithProduct.length,
                    totalValue: totalValue,
                    productBreakdown,
                    reportType: 'Claims by Product',
                };

            case 'COMPLIANCE_AUDIT':
                // Joining AuditLog with User to get email
                const logsWithUser = await this.auditRepo.createQueryBuilder('log')
                    .leftJoin(User, 'user', 'user.id = log.performedBy')
                    .select([
                        'log.occurredAt as occurredAt',
                        'log.action as action',
                        'log.entityType as entityType',
                        'user.email as userEmail'
                    ])
                    .where('log.tenantId = :tenantId', { tenantId })
                    .andWhere('log.occurredAt BETWEEN :start AND :end', { start, end })
                    .orderBy('log.occurredAt', 'DESC')
                    .limit(100)
                    .getRawMany();

                return {
                    totalEntries: logsWithUser.length,
                    activities: logsWithUser.map((l) => ({
                        date: new Date(l.occurredat).toISOString().split('T')[0],
                        time: new Date(l.occurredat)
                            .toISOString()
                            .split('T')[1]
                            .substring(0, 5),
                        action: l.action,
                        category: l.entitytype,
                        performedBy: l.useremail || 'System',
                    })),
                    reportType: 'Compliance Audit',
                };

            default:
                return {
                    reportType: type,
                    timestamp: new Date().toISOString(),
                    message: 'Manual Report Data',
                };
        }
    }

    async exportToFile(
        tenantId: string,
        type: string,
        format: string,
        fromDate?: string,
        toDate?: string,
    ): Promise<Buffer> {
        const data = await this.generateSummary(tenantId, type, fromDate, toDate);

        if (format === 'xlsx') {
            const workbook = new ExcelJS.Workbook();
            const sheet = workbook.addWorksheet('Report');
            sheet.addRow([`Report: ${data.reportType}`]);
            sheet.addRow([
                `Date Range: ${fromDate || 'Start'} to ${toDate || 'Now'}`,
            ]);
            sheet.addRow([]);

            if (type === 'COMPLIANCE_AUDIT') {
                sheet.addRow(['Date', 'Time', 'Action', 'Category', 'Performed By (Email)']);
                (data.activities || []).forEach((a: any) =>
                    sheet.addRow([a.date, a.time, a.action, a.category, a.performedBy]),
                );
            } else if (type === 'CLAIMS_BY_PRODUCT') {
                sheet.addRow(['Product', 'Claims Count', 'Total Claimed Amount']);
                Object.entries(data.productBreakdown || {}).forEach(
                    ([p, s]: [string, any]) =>
                        sheet.addRow([p, s.count, s.totalAmount]),
                );
            } else {
                Object.entries(data).forEach(
                    ([k, v]) =>
                        k !== 'reportType' &&
                        sheet.addRow([
                            k,
                            typeof v === 'object' ? JSON.stringify(v) : v,
                        ]),
                );
            }

            const buf = await workbook.xlsx.writeBuffer();
            return Buffer.from(buf);
        } else {
            return new Promise((resolve, reject) => {
                const doc = new PDFDocument({ margin: 30, size: 'A4' });
                const chunks: any[] = [];
                doc.on('data', (chunk) => chunks.push(chunk));
                doc.on('end', () => resolve(Buffer.concat(chunks)));
                doc.on('error', reject);

                // Styling tokens
                const colors = {
                    primary: '#1E2A5E',
                    headerBg: '#F4F7F9',
                    border: '#DDE3E9',
                    text: '#2C3E50',
                    subtext: '#7F8C8D',
                };

                // Header Banner
                doc.rect(0, 0, 595, 70).fill(colors.primary);
                doc.fontSize(20).fillColor('#FFFFFF').text('INSUREFLOW AUDIT JOURNAL', 35, 25);
                doc.fontSize(9).text('SECURE ANALYTICS & COMPLIANCE ENGINE', 35, 48);

                doc.moveDown(4);
                doc.fontSize(16).fillColor(colors.primary).text(data.reportType);
                doc.fontSize(8).fillColor(colors.subtext).text(`Report Period: ${fromDate || 'All'} to ${toDate || 'Latest'}`);
                doc.text(`Run Time: ${new Date().toISOString()}`);
                doc.moveDown(2);

                if (type === 'COMPLIANCE_AUDIT') {
                    const tableX = 35;
                    const colWidths = [100, 140, 80, 200];
                    const colX = [
                        tableX,
                        tableX + colWidths[0],
                        tableX + colWidths[0] + colWidths[1],
                        tableX + colWidths[0] + colWidths[1] + colWidths[2]
                    ];

                    // Draw Table Headers
                    let currentY = doc.y;
                    doc.rect(tableX, currentY, 520, 25).fill(colors.headerBg);
                    doc.fillColor(colors.primary).font('Helvetica-Bold').fontSize(9);

                    doc.text('TIMESTAMP (UTC)', colX[0] + 5, currentY + 8);
                    doc.text('ACTION', colX[1] + 5, currentY + 8);
                    doc.text('CATEGORY', colX[2] + 5, currentY + 8);
                    doc.text('PERFORMED BY (EMAIL)', colX[3] + 5, currentY + 8);

                    currentY += 25;
                    doc.moveTo(tableX, currentY).lineTo(tableX + 520, currentY).strokeColor(colors.border).stroke();

                    // Body Items
                    doc.font('Helvetica').fontSize(8).fillColor(colors.text);

                    (data.activities || []).forEach((a: any) => {
                        if (currentY > 750) {
                            doc.addPage();
                            currentY = 50;
                            // Redraw header on new page
                            doc.rect(tableX, currentY, 520, 25).fill(colors.headerBg);
                            doc.fillColor(colors.primary).font('Helvetica-Bold').fontSize(9);
                            doc.text('TIMESTAMP (UTC)', colX[0] + 5, currentY + 8);
                            doc.text('ACTION', colX[1] + 5, currentY + 8);
                            doc.text('CATEGORY', colX[2] + 5, currentY + 8);
                            doc.text('PERFORMED BY (EMAIL)', colX[3] + 5, currentY + 8);
                            currentY += 25;
                            doc.font('Helvetica').fontSize(8).fillColor(colors.text);
                        }

                        // Draw line items
                        doc.text(`${a.date} ${a.time}`, colX[0] + 5, currentY + 7);
                        doc.text(a.action, colX[1] + 5, currentY + 7);
                        doc.text(a.category, colX[2] + 5, currentY + 7);
                        doc.text(a.performedBy || 'System', colX[3] + 5, currentY + 7, { width: 190 });

                        currentY += 20;
                        doc.moveTo(tableX, currentY).lineTo(tableX + 520, currentY).strokeColor(colors.border).lineWidth(0.5).stroke();
                    });

                } else if (type === 'CLAIMS_BY_PRODUCT') {
                    doc.fontSize(14).fillColor(colors.primary).text('Claims Summary Distribution');
                    doc.moveDown();
                    Object.entries(data.productBreakdown || {}).forEach(([p, s]: [string, any]) => {
                        doc.font('Helvetica-Bold').fontSize(10).fillColor(colors.text).text(p);
                        doc.font('Helvetica').fontSize(9).fillColor(colors.subtext).text(`Total: ${s.count} claims | Value: ₹${s.totalAmount.toLocaleString('en-IN')}`);
                        doc.moveDown(0.5);
                        doc.rect(doc.x, doc.y, 500, 1).fill(colors.border);
                        doc.moveDown(0.8);
                    });
                }

                doc.end();
            });
        }
    }
}
