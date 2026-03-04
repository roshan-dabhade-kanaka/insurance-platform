import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import {
    UnderwritingCase,
    UnderwritingLock,
    UnderwritingDecision,
    ApprovalHierarchy,
    ApprovalHierarchyLevel,
} from './entities/underwriting.entity';
import { UnderwritingService } from './services/underwriting.service';
import { UnderwritingController } from './controllers/underwriting.controller';
import { TemporalModule } from '../../temporal/worker/worker';

@Module({
    imports: [
        TypeOrmModule.forFeature([
            UnderwritingCase,
            UnderwritingLock,
            UnderwritingDecision,
            ApprovalHierarchy,
            ApprovalHierarchyLevel,
        ]),
        TemporalModule,
    ],
    providers: [UnderwritingService],
    controllers: [UnderwritingController],
    exports: [UnderwritingService],
})
export class UnderwritingModule { }
