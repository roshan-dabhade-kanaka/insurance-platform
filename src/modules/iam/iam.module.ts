import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { User, Role, Permission } from './entities/user.entity';
import { AuthService } from './services/auth.service';
import { UserService } from './services/user.service';
import { AuthController } from './controllers/auth.controller';
import { UserController } from './controllers/user.controller';
import { JwtStrategy } from './strategies/jwt.strategy';
import { NotificationConfig } from './entities/notification-config.entity';
import { NotificationService } from './services/notification.service';
import { NotificationController } from './controllers/notification.controller';

@Module({
    imports: [
        ConfigModule,
        TypeOrmModule.forFeature([User, Role, Permission, NotificationConfig]),
        PassportModule,
        JwtModule.registerAsync({
            imports: [ConfigModule],
            inject: [ConfigService],
            useFactory: async (configService: ConfigService) => ({
                secret: configService.get<string>('JWT_SECRET', 'super-secret-key'),
                signOptions: { expiresIn: '1h' },
            }),
        }),
    ],
    providers: [AuthService, UserService, JwtStrategy, NotificationService],
    controllers: [AuthController, UserController, NotificationController],
    exports: [AuthService, UserService, JwtModule, NotificationService],
})
export class IamModule { }
