import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { AppModule } from './app.module';

async function bootstrap() {
    const logger = new Logger('Bootstrap');
    const app = await NestFactory.create(AppModule);

    app.enableCors({ origin: true }); // Allow browser requests from any origin (e.g. Flutter web)

    // Global prefixes and pipes
    app.setGlobalPrefix('api');
    app.useGlobalPipes(
        new ValidationPipe({
            whitelist: true,
            transform: true,
            forbidNonWhitelisted: true,
        }),
    );

    // Swagger Documentation
    const config = new DocumentBuilder()
        .setTitle('Insurance Policy Configuration & Underwriting Platform API')
        .setDescription('The API documentation for the multi-tenant insurance platform.')
        .setVersion('1.0')
        .addTag('quotes')
        .addTag('underwriting')
        .addTag('policies')
        .addTag('claims')
        .addTag('finance')
        .addTag('audit')
        .addBearerAuth()
        .build();
    const document = SwaggerModule.createDocument(app, config);
    SwaggerModule.setup('docs', app, document);

    let port = parseInt(process.env.PORT || '3000', 10);
    const maxPort = port + 10;
    while (true) {
        try {
            await app.listen(port);
            break;
        } catch (err: unknown) {
            const code = (err as NodeJS.ErrnoException)?.code;
            if (code === 'EADDRINUSE' && port < maxPort) {
                logger.warn(`Port ${port} in use, trying ${port + 1}...`);
                port++;
            } else {
                throw err;
            }
        }
    }
    logger.log(`Application is running on: http://localhost:${port}/api`);
    logger.log(`Swagger documentation available at: http://localhost:${port}/docs`);
}
bootstrap();
