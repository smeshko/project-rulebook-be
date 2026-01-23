---
title: "Troubleshooting Guide"
description: "Common issues and solutions for project-rulebook-be development"
author: Claude
date: 2026-01-23
---

# Troubleshooting Guide

Common issues and their solutions when developing project-rulebook-be.

---

## Development Services

### Docker Services Not Starting

```bash
# Check if Docker services are running
docker-compose -f docker-compose.dev.yml ps

# View service logs
docker-compose -f docker-compose.dev.yml logs postgres
docker-compose -f docker-compose.dev.yml logs redis

# Restart services if needed
docker-compose -f docker-compose.dev.yml restart
```

### Database Connection Issues

```bash
# Test PostgreSQL connection
docker exec -it project_rulebook_postgres_dev psql -U vapor -d project_rulebook_dev

# Test Redis connection
docker exec -it project_rulebook_redis_dev redis-cli ping
```

---

## Authentication

### JWT Errors

```bash
# JWT_KEY must be at least 32 characters
echo $JWT_KEY | wc -c
```

Ensure your `.env` file has a properly configured JWT_KEY.

### Admin User Verification

```bash
# Verify admin user creation
curl -X POST http://localhost:8080/api/v1/auth/sign-in \
  -H "Content-Type: application/json" \
  -d '{"email":"root@localhost.com","password":"ChangeMe1"}'
```

---

## Network & Ports

### Port Already in Use

```bash
# Find process using port 8080
lsof -i :8080

# Kill the process or use a different port
swift run App serve --port 8081
```

---

## API Issues

### Rate Limiting

```bash
# Check rate limit headers in responses
curl -I http://localhost:8080/api/v1/rules-generation/rules-summary

# Expected headers:
# X-RateLimit-Limit: 10
# X-RateLimit-Remaining: 9
# X-RateLimit-Type: rules_generation
```

### Cache Issues

```bash
# Check cache health (requires admin auth)
curl -H "Authorization: Bearer YOUR_TOKEN" \
     http://localhost:8080/api/admin/cache/health

# Clear cache if needed
curl -X DELETE -H "Authorization: Bearer YOUR_TOKEN" \
     http://localhost:8080/api/admin/cache
```

---

## Performance

### Performance Optimization Tips

- Monitor cache hit rates (target >70% for cost savings)
- Adjust TTL values based on usage patterns
- Scale database connections for high load
- Use CDN for static assets in production

---

## Getting Help

- Check documentation in `docs/`
- Review test files for usage examples
- Examine existing module implementations for patterns
- Create issues for bugs or feature requests
