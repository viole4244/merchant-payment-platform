package global

import (
	"context"
	"fmt"
	"log"
	"os"
	"strconv"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/joho/godotenv"
)

// DB is the global connection pool shared across the entire application.
var DB *pgxpool.Pool

// InitDB loads config from .env, connects to PostgreSQL, and sets the global DB pool.
// Call this once at startup from main.go before doing anything else.
func InitDB() error {
	// Load .env file — silently skip if not present (prod uses real env vars)
	_ = godotenv.Load()

	dsn, err := buildDSN()
	if err != nil {
		return err
	}

	cfg, err := pgxpool.ParseConfig(dsn)
	if err != nil {
		return fmt.Errorf("parse db config: %w", err)
	}

	cfg.MaxConns = int32(getEnvInt("DB_MAX_CONNS", 25))
	cfg.MinConns = int32(getEnvInt("DB_MIN_CONNS", 5))
	cfg.MaxConnLifetime = 1 * time.Hour
	cfg.MaxConnIdleTime = 30 * time.Minute
	cfg.HealthCheckPeriod = 1 * time.Minute

	pool, err := pgxpool.NewWithConfig(context.Background(), cfg)
	if err != nil {
		return fmt.Errorf("create pool: %w", err)
	}

	// Ping to validate the connection immediately
	if err := pool.Ping(context.Background()); err != nil {
		pool.Close()
		return fmt.Errorf("ping failed — check DB_HOST, DB_PORT, DB_USER, DB_PASSWORD: %w", err)
	}

	DB = pool

	log.Printf("✅ Connected to PostgreSQL  host=%s  db=%s  pool=[%d–%d]",
		getEnv("DB_HOST", "localhost"),
		getEnv("DB_NAME", "mdr"),
		cfg.MinConns, cfg.MaxConns,
	)

	return nil
}

// CloseDB closes the connection pool. Call via defer in main().
func CloseDB() {
	if DB != nil {
		DB.Close()
		log.Println("🔌 DB connection pool closed")
	}
}

// buildDSN constructs the postgres:// connection string from env vars.
func buildDSN() (string, error) {
	password := os.Getenv("DB_PASSWORD")
	if password == "" {
		return "", fmt.Errorf("DB_PASSWORD environment variable is not set")
	}

	return fmt.Sprintf(
		"postgres://%s:%s@%s:%s/%s?sslmode=%s",
		getEnv("DB_USER", "postgres"),
		password,
		getEnv("DB_HOST", "localhost"),
		getEnv("DB_PORT", "5432"),
		getEnv("DB_NAME", "mdr"),
		getEnv("DB_SSL_MODE", "disable"),
	), nil
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		if i, err := strconv.Atoi(v); err == nil {
			return i
		}
	}
	return fallback
}
