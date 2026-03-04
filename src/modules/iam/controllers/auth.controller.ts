import { Controller, Post, Body, UnauthorizedException, HttpCode, HttpStatus } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBody, ApiResponse } from '@nestjs/swagger';
import { AuthService } from '../services/auth.service';
import { Public } from '../decorators/public.decorator';

@ApiTags('auth')
@Controller('auth')
export class AuthController {
    constructor(private authService: AuthService) { }

    @Public()
    @Post('login')
    @HttpCode(HttpStatus.OK)
    @ApiOperation({ summary: 'User login with email and password' })
    @ApiBody({
        schema: {
            type: 'object',
            properties: {
                email: { type: 'string', example: 'admin@insurance.com' },
                password: { type: 'string', example: 'Admin@123' },
            },
        },
        examples: {
            admin: { value: { email: 'admin@insurance.com', password: 'Admin@123' }, summary: 'Admin Login' },
            agent: { value: { email: 'agent@insurance.com', password: 'Agent@123' }, summary: 'Agent Login' },
            underwriter: { value: { email: 'uw@insurance.com', password: 'UW@123' }, summary: 'Underwriter Login' },
            seniorUnderwriter: { value: { email: 'senioruw@insurance.com', password: 'SeniorUW@123' }, summary: 'Senior Underwriter Login' },
            claimsOfficer: { value: { email: 'claims@insurance.com', password: 'Claims@123' }, summary: 'Claims Officer Login' },
            fraudAnalyst: { value: { email: 'fraud@insurance.com', password: 'Fraud@123' }, summary: 'Fraud Analyst Login' },
            financeOfficer: { value: { email: 'finance@insurance.com', password: 'Finance@123' }, summary: 'Finance Officer Login' },
            complianceOfficer: { value: { email: 'compliance@insurance.com', password: 'Compliance@123' }, summary: 'Compliance Officer Login' },
            customer: { value: { email: 'customer@insurance.com', password: 'Customer@123' }, summary: 'Customer Login' },
        }
    })
    @ApiResponse({ status: 200, description: 'JWT token returned on success' })
    @ApiResponse({ status: 401, description: 'Invalid credentials' })
    async login(@Body() loginDto: any) {
        const user = await this.authService.validateUser(loginDto.email, loginDto.password);
        if (!user) {
            throw new UnauthorizedException('Invalid credentials');
        }
        return this.authService.login(user);
    }
}
