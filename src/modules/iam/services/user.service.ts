import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../entities/user.entity';

@Injectable()
export class UserService {
    constructor(
        @InjectRepository(User)
        private readonly userRepo: Repository<User>,
    ) { }

    async findAll(tenantId: string): Promise<User[]> {
        return this.userRepo.find({
            where: { tenantId },
            relations: ['roles'],
            order: { firstName: 'ASC' },
        });
    }
}
