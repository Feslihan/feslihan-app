CREATE TABLE "device_tokens" (
	"token" varchar(200) PRIMARY KEY NOT NULL,
	"user_id" varchar(255) NOT NULL,
	"environment" varchar(12) DEFAULT 'production' NOT NULL,
	"updated_at" timestamp with time zone DEFAULT now() NOT NULL
);
--> statement-breakpoint
ALTER TABLE "device_tokens" ADD CONSTRAINT "device_tokens_user_id_users_clerk_id_fk" FOREIGN KEY ("user_id") REFERENCES "public"."users"("clerk_id") ON DELETE no action ON UPDATE no action;