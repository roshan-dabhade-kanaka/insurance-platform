System Name:
Insurance Policy Configuration & Underwriting Platform

System Type:
Multi-tenant enterprise insurance lifecycle platform.

Architecture Style:
Microservices + Workflow Orchestrated + Rule Driven

Frontend:
Flutter Web (Admin + Agent)
Flutter Mobile (Customer)

Backend:
NestJS Microservices Architecture

Database:
PostgreSQL

Rule Engine:
json-rules-engine

Workflow Engine:
Temporal

Core Services:

* Product Configuration Service
* Coverage Configuration Service
* Risk Profiling Service
* Premium Calculation Service
* Quote Lifecycle Service
* Underwriting Service
* Policy Issuance Service
* Claim Service
* Fraud Detection Service
* Finance Payout Service
* Compliance Audit Service

System Characteristics:

* Multi-tenant
* Config driven UI
* Rule driven underwriting
* Versioned product engine
* Event logged lifecycle transitions
* Concurrent underwriting protection

Performance Requirements:

* Quote generation < 300ms
* Risk scoring < 200ms
* Claim validation < 200ms
* 10k concurrent users
* 99.99% uptime

All eligibility rules must be stored in JSONB.
All lifecycle transitions must be audit logged.
All underwriting approvals must be workflow orchestrated.
