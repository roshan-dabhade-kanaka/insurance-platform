import { Injectable, OnApplicationBootstrap, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { User, Role, UserStatus, UserRole } from '../iam/entities/user.entity';
import { Tenant } from '../tenant/entities/tenant.entity';

@Injectable()
export class SeedService implements OnApplicationBootstrap {
    private readonly logger = new Logger(SeedService.name);
    /** Fixed UUID for seed data so tenant_id column (uuid type) is valid */
    private readonly DEFAULT_TENANT_ID = '00000000-0000-0000-0000-000000000001';

    constructor(
        @InjectRepository(User)
        private readonly userRepo: Repository<User>,
        @InjectRepository(Role)
        private readonly roleRepo: Repository<Role>,
        @InjectRepository(Tenant)
        private readonly tenantRepo: Repository<Tenant>,
    ) { }

    async onApplicationBootstrap() {
        this.logger.log('Starting database seeding...');
        await this.seedTenants();
        await this.seedRoles();
        await this.seedUsers();
        this.logger.log('Database seeding completed.');
    }

    public async seedTenants() {
        const existing = await this.tenantRepo.findOne({
            where: { id: this.DEFAULT_TENANT_ID },
        });

        if (!existing) {
            const tenant = this.tenantRepo.create({
                id: this.DEFAULT_TENANT_ID,
                name: 'Main Insurance Tenant',
                slug: 'main-tenant',
                isActive: true,
            });
            await this.tenantRepo.save(tenant);
            this.logger.log('Created default tenant.');
        }
    }

    public async seedRoles() {
        const rolesToSeed = Object.values(UserRole);

        for (const roleName of rolesToSeed) {
            const existingRole = await this.roleRepo.findOne({
                where: { name: roleName, tenantId: this.DEFAULT_TENANT_ID },
            });

            if (!existingRole) {
                const newRole = this.roleRepo.create({
                    name: roleName,
                    tenantId: this.DEFAULT_TENANT_ID,
                    isSystemRole: true,
                    description: `System defined ${roleName} role`,
                });
                await this.roleRepo.save(newRole);
                this.logger.log(`Created role: ${roleName}`);
            }
        }
    }

    public async seedUsers() {
        const usersToSeed = [
            { email: 'admin@insurance.com', password: 'Admin@123', role: UserRole.ADMIN, first: 'System', last: 'Admin' },
            { email: 'agent@insurance.com', password: 'Agent@123', role: UserRole.AGENT, first: 'Standard', last: 'Agent' },
            { email: 'uw@insurance.com', password: 'UW@123', role: UserRole.UNDERWRITER, first: 'Junior', last: 'Underwriter' },
            { email: 'senioruw@insurance.com', password: 'SeniorUW@123', role: UserRole.SENIOR_UNDERWRITER, first: 'Senior', last: 'Underwriter' },
            { email: 'claims@insurance.com', password: 'Claims@123', role: UserRole.CLAIMS_OFFICER, first: 'Claims', last: 'Officer' },
            { email: 'fraud@insurance.com', password: 'Fraud@123', role: UserRole.FRAUD_ANALYST, first: 'Fraud', last: 'Analyst' },
            { email: 'finance@insurance.com', password: 'Finance@123', role: UserRole.FINANCE_OFFICER, first: 'Finance', last: 'Officer' },
            { email: 'compliance@insurance.com', password: 'Compliance@123', role: UserRole.COMPLIANCE_OFFICER, first: 'Compliance', last: 'Officer' },
            { email: 'customer@insurance.com', password: 'Customer@123', role: UserRole.CUSTOMER, first: 'Valued', last: 'Customer' },
        ];

        for (const userData of usersToSeed) {
            const existingUser = await this.userRepo.findOne({
                where: { email: userData.email, tenantId: this.DEFAULT_TENANT_ID },
            });

            if (!existingUser) {
                const role = await this.roleRepo.findOne({
                    where: { name: userData.role, tenantId: this.DEFAULT_TENANT_ID },
                });

                if (role) {
                    const passwordHash = await bcrypt.hash(userData.password, 10);
                    const newUser = this.userRepo.create({
                        email: userData.email,
                        passwordHash,
                        firstName: userData.first,
                        lastName: userData.last,
                        status: UserStatus.ACTIVE,
                        tenantId: this.DEFAULT_TENANT_ID,
                        roles: [role],
                    });
                    await this.userRepo.save(newUser);
                    this.logger.log(`Created user: ${userData.email} with role ${userData.role}`);
                }
            }
        }
    }
}
