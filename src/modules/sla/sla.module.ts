import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { SlaController } from './sla.controller';
import { SlaService } from './services/sla.service';
import { Quote } from '../quote/entities/quote.entity';
import { Claim } from '../claim/entities/claim.entity';

@Module({
    imports: [TypeOrmModule.forFeature([Quote, Claim])],
    controllers: [SlaController],
    providers: [SlaService],
})
export class SlaModule { }
