package main

import (
	"context"
	"log"

	"merchantpay/global"
	"merchantpay/utils"
)

func main() {
	log.SetFlags(log.Ltime | log.Lshortfile)

	// Step 1: Connect to PostgreSQL
	if err := global.InitDB(); err != nil {
		log.Fatalf("❌ DB init failed: %v", err)
	}
	defer global.CloseDB()

	// Step 2: Create all tables, indexes, and seed reference data
	if err := utils.RunInitQueries(context.Background(), global.DB); err != nil {
		log.Fatalf("❌ Table init failed: %v", err)
	}

	log.Println("🚀 Server ready — all tables initialized")

	// TODO: Start HTTP/gRPC server here
}
