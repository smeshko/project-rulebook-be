#!/bin/bash

# Development Services Management Script
# Usage: ./dev-services.sh [start|stop|restart|logs|clean|status]

set -e

COMPOSE_FILE="docker-compose.dev.yml"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$PROJECT_DIR"

case "${1:-help}" in
    start)
        echo "🚀 Starting development services..."
        docker-compose -f "$COMPOSE_FILE" up -d
        echo "✅ Services started. Use 'docker-compose -f $COMPOSE_FILE logs -f' to view logs"
        ;;
    stop)
        echo "🛑 Stopping development services..."
        docker-compose -f "$COMPOSE_FILE" down
        echo "✅ Services stopped"
        ;;
    restart)
        echo "🔄 Restarting development services..."
        docker-compose -f "$COMPOSE_FILE" down
        docker-compose -f "$COMPOSE_FILE" up -d
        echo "✅ Services restarted"
        ;;
    logs)
        echo "📋 Showing service logs (Ctrl+C to exit)..."
        docker-compose -f "$COMPOSE_FILE" logs -f
        ;;
    clean)
        read -p "⚠️  This will delete all development data. Are you sure? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "🧹 Cleaning up development environment..."
            docker-compose -f "$COMPOSE_FILE" down -v
            docker system prune -f
            echo "✅ Development environment cleaned"
        else
            echo "❌ Clean up cancelled"
        fi
        ;;
    status)
        echo "📊 Development services status:"
        docker-compose -f "$COMPOSE_FILE" ps
        echo
        echo "🔍 Health checks:"
        docker-compose -f "$COMPOSE_FILE" ps --format "table {{.Name}}\t{{.Status}}"
        ;;
    help|*)
        echo "🛠️  Development Services Manager"
        echo
        echo "Usage: $0 [command]"
        echo
        echo "Commands:"
        echo "  start    - Start PostgreSQL and Redis services"
        echo "  stop     - Stop all services"
        echo "  restart  - Restart all services"
        echo "  logs     - Show service logs (follow mode)"
        echo "  clean    - Stop services and remove all data volumes"
        echo "  status   - Show service status and health"
        echo "  help     - Show this help message"
        echo
        echo "Examples:"
        echo "  $0 start          # Start services"
        echo "  $0 logs           # Follow logs"
        echo "  $0 status         # Check status"
        ;;
esac