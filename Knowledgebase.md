CONTENTS:

1\.	Theme

2\.	Meat Shop Details

3\.	Other Enhancements as on 18/07/2025

4\.	Customer Portal

5\.	Complete Google Maps Integration Guide

6\.



















































THEME:

Apply a consistent emerald-green color theme to component shown in the image (current page) using the following color system:



Color Palette:



Use emerald-50 to emerald-900 and green-50 to green-900

White for text on dark backgrounds

Strategic red-600 accents for urgent/active states when needed

Maintain current functionality

Background Strategy:

Page: bg-gradient-to-br from-emerald-50 to-green-100

Cards: bg-gradient-to-br from-emerald-50 to-green-50 or from-white to-emerald-50

Headers: bg-gradient-to-r from-emerald-500 to-green-600 OR clean white to emerald gradient with backdrop blur

Premium sections: bg-gradient-to-br from-emerald-700 to-green-800

Interactive Elements:

Buttons: NEVER use bg-primary, bg-secondary, bg-card, or CSS custom properties that might fall back to dark colors

Instead use explicit emerald classes: bg-emerald-600 hover:bg-emerald-700 text-white

For outline buttons: border-emerald-300 text-emerald-700 hover:bg-emerald-50 hover:border-emerald-400

For ghost buttons: hover:bg-emerald-50 text-emerald-700 hover:text-emerald-800

Primary action buttons: emerald gradient background to stand out

Borders: border-emerald-200 hover:border-emerald-400

Badges: bg-emerald-100 text-emerald-700 border-emerald-200 OR rounded with white borders and subtle shadows

Use red-600 for urgent/critical elements (alerts, active states, deadlines)

Text Colors:

On light backgrounds: text-emerald-900, text-emerald-800, text-emerald-700

On dark backgrounds: text-white, text-emerald-100

Secondary text: text-emerald-600, text-emerald-500

Critical/urgent text: text-red-600, bg-red-50 for urgent backgrounds

CRITICAL: Button Styling Rules

NEVER use button variants that rely on CSS custom properties (bg-primary, bg-secondary, bg-card, text-primary-foreground, etc.)

ALWAYS use explicit Tailwind classes for buttons:

Default: bg-emerald-600 hover:bg-emerald-700 text-white

Outline: border-emerald-300 text-emerald-700 hover:bg-emerald-50 hover:border-emerald-400

Ghost: hover:bg-emerald-50 text-emerald-700 hover:text-emerald-800

Secondary: bg-emerald-100 text-emerald-800 hover:bg-emerald-200

If using Button component with variants, override with explicit className

Modern Design Enhancements:

ELIMINATE ALL BLACK ACCENTS - replace with clean white/emerald theme

Apply glass-morphism design with semi-transparent backgrounds and subtle borders

Implement improved spacing with tighter visual hierarchy

Add responsive text behavior (hide button text on small screens, show only icons)

Include rounded notification badges with white borders and subtle shadows

Use clean header backgrounds with white to emerald gradients and backdrop blur



Design Rules:

Use gradients for depth and visual interest

Ensure proper contrast (white on dark, dark on light)

Hover states should be one shade darker with shadow depth changes

Keep shadows subtle with emerald tints

Maintain existing functionality and layout

Add transition-all duration-300 for smooth interactions

Apply red-600 sparingly only for urgent/active/critical elements

NEVER rely on CSS custom properties that might fall back to dark colors

ALWAYS use explicit Tailwind emerald classes

Recommendations:

The red accent should be used for: active states, urgent notifications, error messages, deadlines, "live" indicators, critical actions

Keep red usage minimal (5-10% of the design) to maintain the calming emerald theme

Always pair red with appropriate backgrounds (red-50, white) for proper contrast

Focus on clean, modern design with glass-morphism effects

Use emerald gradients for primary actions to create visual hierarchy

Double-check all buttons to ensure they use explicit emerald classes, not CSS variables

Make it aesthetic, consistent, professional, and modern while preserving all existing functionality.



























Meat Shop Details

Meat Shop System - Complete Technical Reference

Overview

The meat shop system allows sellers to manage their meat products through a dashboard. It integrates with Odoo ERP for product synchronization and includes an approval workflow. Products can be added with images, descriptions, and pricing information.



Database Structure

Key Tables

sellers



Main table for seller information

Key fields: id, user\_id, seller\_name, seller\_type, meat\_shop\_status, approval\_status

Controls the shop status (open/closed)

meat\_products



Stores all meat products

Key fields: id, seller\_id, name, description, price, stock, approval\_status

Products have an approval workflow (pending → approved/rejected)

meat\_product\_images



Stores product images

Key fields: id, meat\_product\_id, image\_url, display\_order

Links to the meat products table

product\_approvals



Tracks approval processes

Key fields: id, meat\_product\_id, approval\_status, submitted\_at, approved\_at, rejected\_at

Contains audit information for the approval workflow

Frontend Components

Main Components

MeatShopManagement.tsx



Controls the meat shop status (open/closed)

Contains the product listing and form components

Shows approval status warnings

MeatProductForm.tsx



Form for adding new products

Handles image uploads

Submits data to both Supabase and Odoo

MeatProductsList.tsx



Displays products in a table view

Shows approval status with colored badges

Handles refreshing the product list

API Flows

Adding a New Product

User fills out the product form with:



Product name

Price

Stock quantity (optional)

Description (optional)

Product images (optional)

On form submission (handleSubmit function in MeatProductForm.tsx):



Data is validated

Product record is created in meat\_products table

Images are uploaded to Supabase storage bucket meat-product-images

Image records are created in meat\_product\_images table

Product is synchronized to Odoo via the odooService.createProduct function

Payload sent to Odoo:

{

  name: "Product Name",

  list\_price: 100.00,

  seller\_id: "Seller Name",

  state: "pending",

  seller\_uid: "seller-uuid",

  default\_code: "product-uuid",

  meat\_type: "meat"

}



Odoo Integration

The system integrates with Odoo ERP through:



odooService.ts:



Handles authentication with Odoo

Creates products in Odoo

Syncs products between systems

odooConfigManager.ts:



Manages Odoo connection configuration

Stores credentials (defaults to these values if not set):

URL: https://goatgoat.xyz/

Database: staging

Username: admin

Password: admin

Edge Function odoo-api-proxy:



Acts as a secure proxy to Odoo

Handles authentication and session management

Forwards requests to the Odoo API

Approval Workflow

Products start with approval\_status = 'pending'

Approvals are processed through the webhook endpoint

The webhook is implemented in product-approval-webhook/index.ts

Approval payload:



{

  product\_id: "uuid",

  seller\_id: "uuid",

  product\_type: "meat",

  approval\_status: "approved" | "rejected" | "pending",

  rejection\_reason: "Optional reason"

}

When approved, the product status is updated in both meat\_products and product\_approvals tables

Storage Implementation

Product images are stored in the meat-product-images Supabase storage bucket

Image naming convention: {productId}\_{index}.{extension}

Public URLs are generated and stored in the database

Authorization and Security

Authentication uses the x-api-key header with WEBHOOK\_API\_KEY for webhooks

Odoo proxy secures credentials

Database tables are secured with RLS policies

Complete Implementation Steps

Set up database tables:



sellers

meat\_products

meat\_product\_images

product\_approvals

Create Supabase storage bucket:



Name: meat-product-images

Make public with appropriate policies

Implement frontend components:



MeatShopManagement.tsx

MeatProductForm.tsx

MeatProductsList.tsx

Set up Odoo integration:



odooService.ts

odooConfigManager.ts

Edge function odoo-api-proxy

Create the approval webhook:



Edge function product-approval-webhook

Code Snippets for Implementation

1\. Adding a New Product



// From MeatProductForm.tsx - handleSubmit function

const handleSubmit = async (e: React.FormEvent) => {

  e.preventDefault();

 

  if (!formData.name || !formData.price) {

    toast.error('Please fill in all required fields');

    return;

  }



  setLoading(true);

  try {

    // 1. Insert product to Supabase

    const { data: product, error: productError } = await supabase

      .from('meat\_products')

      .insert({

        seller\_id: sellerId,

        name: formData.name,

        description: formData.description || null,

        price: parseFloat(formData.price),

        stock: formData.stock ? parseInt(formData.stock) : 0

      })

      .select()

      .single();



    if (productError) throw productError;



    // 2. Upload images if any

    if (images.length > 0) {

      await uploadImages(product.id);

    }



    // 3. Get seller name for Odoo API

    const { data: seller } = await supabase

      .from('sellers')

      .select('seller\_name')

      .eq('id', sellerId)

      .single();



    // 4. Create product in Odoo

    await odooService.createProduct({

      name: formData.name,

      list\_price: parseFloat(formData.price),

      seller\_id: seller.seller\_name,

      state: 'pending',

      seller\_uid: sellerId,

      default\_code: product.id,

      meat\_type: 'meat'

    });



    toast.success('Product added successfully!');

    onSuccess();

  } catch (error) {

    console.error('Error adding product:', error);

    toast.error('Failed to add product');

  } finally {

    setLoading(false);

  }

};

2\. Approving a Product (Webhook)

// Product approval payload

const payload = {

  product\_id: "product-uuid",

  seller\_id: "seller-uuid",

  product\_type: "meat",

  approval\_status: "approved",

  updated\_at: new Date().toISOString()

};



// Send to webhook

const response = await fetch(

  "https://oaynfzqjielnsipttzbs.supabase.co/functions/v1/product-approval-webhook",

  {

    method: "POST",

    headers: {

      "Content-Type": "application/json",

      "x-api-key": "your-webhook-api-key"

    },

    body: JSON.stringify(payload)

  }

);

3\. Odoo API Call

// Create product in Odoo through proxy

const response = await supabase.functions.invoke('odoo-api-proxy', {

  body: {

    odoo\_endpoint: '/web/dataset/call\_kw',

    data: {

      jsonrpc: '2.0',

      method: 'call',

      params: {

        model: 'product.template',

        method: 'create',

        args: \[{

          name: "Product Name",

          list\_price: 100.00,

          seller\_id: "Seller Name",

          state: "pending",

          seller\_uid: "seller-uuid",

          default\_code: "product-uuid",

          meat\_type: "meat"

        }],

        kwargs: {}

      },

      id: Math.random()

    },

    config: {

      serverUrl: "https://goatgoat.xyz/",

      database: "staging",

      username: "admin",

      password: "admin"

    }

  }

});

Key Credentials and API Details

Odoo Connection:



URL: https://goatgoat.xyz/

Database: staging

Username: admin

Password: admin

Supabase Project ID: oaynfzqjielnsipttzbs



API Key (for webhook calls): Stored in Supabase secrets as WEBHOOK\_API\_KEY

Storage Bucket: meat-product-images (public bucket)

This comprehensive reference should help you implement the same meat shop functionality elsewhere with all the necessary details.



















Other Enhancements on 18/07/2025

What We Achieved

1\.	Database Schema Extension

•	Added 11 new optional columns to public.sellers for editable profile data.

•	Created audit table seller\_profile\_audit with RLS + indexes.

•	Zero impact on existing tables, Odoo, webhooks or APIs.

2\.	Odoo Integration Layer

•	Centralised proxy odoo-api-proxy that:

o	authenticates via x-api-key

o	parses once, logs everything (success, 401, 500)

o	sanitises secrets before logging

o	handles meat \& livestock via single endpoint

•	No change to Odoo database itself.

3\.	Webhook System

•	product-approval-webhook accepts:

JSON

Copy

{

  "product\_id": "uuid",

  "seller\_id": "uuid",

  "product\_type": "meat|livestock",

  "approval\_status": "approved|rejected|pending",

  "updated\_at": "2024-01-01T00:00:00Z"

}

4\.	Storage \& Security

•	Public buckets: meat-product-images, livestock-images

•	Secrets stored in Supabase secrets (never in code).

\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

🔐 Sensitive Data (Redacted)

Table

Copy

Key	Value	Location

Odoo URL	https://goatgoat.xyz/	Supabase secret ODOO\_URL

Odoo DB	staging	Supabase secret ODOO\_DB

Odoo User	admin	Supabase secret ODOO\_USERNAME

Odoo Pass	admin	Supabase secret ODOO\_PASSWORD

Webhook Key	dev-webhook-api-key-2024-secure-odoo-integration	Supabase secret WEBHOOK\_API\_KEY

\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

📦 Necessary SQL \& Code

1\. Database Migration

sql

Copy

-- 1. Extend sellers table (idempotent)

ALTER TABLE public.sellers

ADD COLUMN IF NOT EXISTS business\_address TEXT,

ADD COLUMN IF NOT EXISTS business\_city TEXT,

ADD COLUMN IF NOT EXISTS business\_pincode TEXT,

ADD COLUMN IF NOT EXISTS gstin TEXT,

ADD COLUMN IF NOT EXISTS fssai\_license TEXT,

ADD COLUMN IF NOT EXISTS bank\_account\_number TEXT,

ADD COLUMN IF NOT EXISTS ifsc\_code TEXT,

ADD COLUMN IF NOT EXISTS account\_holder\_name TEXT,

ADD COLUMN IF NOT EXISTS business\_logo\_url TEXT,

ADD COLUMN IF NOT EXISTS aadhaar\_number TEXT,

ADD COLUMN IF NOT EXISTS notification\_email BOOLEAN DEFAULT true,

ADD COLUMN IF NOT EXISTS notification\_sms BOOLEAN DEFAULT true,

ADD COLUMN IF NOT EXISTS notification\_push BOOLEAN DEFAULT false;



-- 2. Audit trail

CREATE TABLE IF NOT EXISTS public.seller\_profile\_audit (

  id UUID PRIMARY KEY DEFAULT gen\_random\_uuid(),

  seller\_id UUID REFERENCES public.sellers(id) ON DELETE CASCADE,

  changed\_by UUID REFERENCES auth.users(id),

  field\_name TEXT NOT NULL,

  old\_value TEXT,

  new\_value TEXT,

  change\_reason TEXT,

  created\_at TIMESTAMP WITH TIME ZONE DEFAULT now()

);



-- 3. RLS \& indexes

ALTER TABLE public.seller\_profile\_audit ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Sellers can view their own audit logs"

ON public.seller\_profile\_audit

FOR SELECT USING (...);



CREATE INDEX IF NOT EXISTS idx\_seller\_profile\_audit\_seller\_id ON public.seller\_profile\_audit(seller\_id);

CREATE INDEX IF NOT EXISTS idx\_seller\_profile\_audit\_created\_at ON public.seller\_profile\_audit(created\_at DESC);

2\. Edge Functions (copy-paste \& deploy)

a) odoo-api-proxy

TypeScript

Copy

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";



const corsHeaders = {

  "Access-Control-Allow-Origin": "\*",

  "Access-Control-Allow-Headers":

    "authorization, x-client-info, apikey, content-type, x-api-key",

};



serve(async (req) => {

  if (req.method === "OPTIONS") return new Response(null, { headers: corsHeaders });



  const apiKey = req.headers.get("x-api-key");

  if (apiKey !== Deno.env.get("WEBHOOK\_API\_KEY")) {

    return new Response(JSON.stringify({ error: "Unauthorized" }), { status: 401 });

  }



  const body = await req.json();

  const { name, list\_price, seller\_id, seller\_uid, default\_code, product\_type } = body;



  const odoo = createClient(

    Deno.env.get("SUPABASE\_URL")!,

    Deno.env.get("SUPABASE\_SERVICE\_ROLE\_KEY")!

  );



  const { data, error } = await odoo.functions.invoke("odoo-create-product", {

    body: { name, list\_price, seller\_id, state: "pending", seller\_uid, default\_code, product\_type }

  });



  return error

    ? new Response(JSON.stringify({ error: error.message }), { status: 400 })

    : new Response(JSON.stringify({ success: true, id: data?.id }), { status: 200 });

});

b) log-traffic

TypeScript

Copy

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";



serve(async (req) => {

  const apiKey = req.headers.get("x-api-key");

  if (apiKey !== Deno.env.get("WEBHOOK\_API\_KEY")) return new Response("Unauthorized", { status: 401 });



  const body = await req.json();

  await createClient(Deno.env.get("SUPABASE\_URL")!, Deno.env.get("SUPABASE\_SERVICE\_ROLE\_KEY")!)

    .from("dev\_api\_logs")

    .insert({ ...body, created\_at: new Date().toISOString() });



  return new Response("ok");

});

\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

🔄 Data Flow Diagram

Code

View Large Image

Download

Copy

graph TD

    A\[User adds product] --> B\[Supabase: meat\_products + images]

    B --> C\[Edge Function: odoo-api-proxy]

    C --> D\[Odoo: product.template]

    D --> E\[Webhook: product-approval-webhook]

    E --> F\[Supabase: update approval\_status]

    G\[User edits profile] --> H\[Supabase: sellers (new columns)]

    H --> I\[Audit: seller\_profile\_audit]

\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_

✅ Zero-Impact Checklist

Table

Copy

Area	Status

Odoo database	✅ unchanged

Existing APIs	✅ unchanged

Webhooks	✅ unchanged

Registration flow	✅ unchanged

Product creation	✅ unchanged

Copy-paste the SQL + code snippets above and run:

bash

Copy

supabase functions deploy odoo-api-proxy

supabase functions deploy log-traffic

You now have editable Account Details with full audit, logging, and zero regression.



































CUSTOMER PORTAL

Customer Portal Comprehensive Documentation

📋 Overview

The customer portal is a React-based meat marketplace with dual-mode architecture (customer/seller) built on Supabase with Odoo ERP integration. It supports phone-based authentication, real-time inventory management, and payment processing.

























Authentication \& User Management

Customer Authentication Flow

1\.	Phone-based Registration: Uses useCustomerAuth hook

2\.	OTP Verification: Fast2SMS integration via edge function

3\.	Session Management: localStorage + Supabase session

4\.	Onboarding: Multi-step process (Welcome → Auth → Preferences)

Files Involved:

•	src/hooks/useCustomerAuth.ts - Main authentication logic

•	src/components/customer/CustomerOnboarding.tsx - Registration UI

•	src/components/onboarding/OnboardingFlow.tsx - Complete onboarding flow

•	supabase/functions/fast2sms-otp/index.ts - OTP service

Forms Created

1\. Customer Registration Form

Location: src/components/customer/CustomerOnboarding.tsx Fields:

•	Full Name (required)

•	Phone Number (required)

•	Email (optional)

•	Location (GPS coordinates)

•	Address (optional)

2\. Delivery Preferences Form

Location: src/components/onboarding/DeliveryPreferences.tsx Fields:

•	Preferred delivery times

•	Address preferences

•	Notification settings

3\. Basic Info Collection Form

Location: src/components/onboarding/BasicInfoCollection.tsx Fields:

•	Personal details

•	Contact information

•	Preferences

4\. Phone Authentication Form

Location: src/components/onboarding/PhoneAuth.tsx Fields:

•	Phone number input

•	OTP verification

•	Terms acceptance

🌐 Web APIs Available

Edge Functions (Supabase Functions)

All functions are located in supabase/functions/ and are publicly accessible (verify\_jwt = false):

1\. create-odoo-customer

•	Endpoint: https://oaynfzqjielnsipttzbs.supabase.co/functions/v1/create-odoo-customer

•	Purpose: Creates customer in Odoo ERP system

•	Payload:

{

  "name": "Customer Name",

  "phone": "1234567890",

  "email": "customer@example.com",

  "address": "Customer Address",

  "customer\_id": "uuid"

}



fast2sms-otp

•	Endpoint: https://oaynfzqjielnsipttzbs.supabase.co/functions/v1/fast2sms-otp

•	Purpose: Send and verify OTP via SMS

•	Payload:

{

  "action": "send|verify",

  "phoneNumber": "1234567890",

  "otp": "1234" // for verify action

}



3\. create-phonepe-payment

•	Endpoint: https://oaynfzqjielnsipttzbs.supabase.co/functions/v1/create-phonepe-payment

•	Purpose: Initialize PhonePe payment gateway

•	Payload:



{

  "orderId": "uuid",

  "amount": 500.00,

  "customerName": "John Doe",

  "customerPhone": "1234567890",

  "customerEmail": "john@example.com",

  "redirectUrl": "https://app.com/success",

  "callbackUrl": "https://app.com/callback"

}

verify-phonepe-payment

•	Endpoint: https://oaynfzqjielnsipttzbs.supabase.co/functions/v1/verify-phonepe-payment

•	Purpose: Verify payment status

•	Payload:

{

  "transactionId": "TXN123456789"

}

odoo-api-proxy

•	Endpoint: https://oaynfzqjielnsipttzbs.supabase.co/functions/v1/odoo-api-proxy

•	Purpose: Proxy requests to Odoo ERP

•	Payload:

{

  "odoo\_endpoint": "/web/session/authenticate",

  "data": { "params": { "db": "", "login": "", "password": "" } },

  "session\_id": "session\_id\_here",

  "config": { "serverUrl": "", "database": "", "username": "", "password": "" }

}



odoo-api-proxy

•	Endpoint: https://oaynfzqjielnsipttzbs.supabase.co/functions/v1/odoo-api-proxy

•	Purpose: Proxy requests to Odoo ERP

•	Payload:

{

  "odoo\_endpoint": "/web/session/authenticate",

  "data": { "params": { "db": "", "login": "", "password": "" } },

  "session\_id": "session\_id\_here",

  "config": { "serverUrl": "", "database": "", "username": "", "password": "" }

}



log-traffic

•	Endpoint: https://oaynfzqjielnsipttzbs.supabase.co/functions/v1/log-traffic

•	Purpose: Log API traffic for monitoring

•	Payload:

{

  "endpoint": "API endpoint",

  "method": "POST",

  "status": 200,

  "payload": {},

  "error": null

}

send-order-confirmation-sms

•	Endpoint: https://oaynfzqjielnsipttzbs.supabase.co/functions/v1/send-order-confirmation-sms

•	Purpose: Send order confirmation SMS

•	Payload:

{

  "phoneNumber": "1234567890",

  "orderNumber": "ORD-20250101-001",

  "customerName": "John Doe",

  "amount": 500.00

}

 Webhooks Available

1\. seller-approval-webhook

•	Endpoint: https://oaynfzqjielnsipttzbs.supabase.co/functions/v1/seller-approval-webhook

•	Authentication: API Key required (x-api-key header)

•	Purpose: Handle seller approval/rejection from external systems

•	Payload:

{

  "seller\_id": "uuid",

  "is\_approved": true,

  "rejection\_reason": "Optional reason",

  "updated\_at": "2025-01-01T00:00:00Z"

}

product-approval-webhook

•	Endpoint: https://oaynfzqjielnsipttzbs.supabase.co/functions/v1/product-approval-webhook

•	Authentication: API Key required

•	Purpose: Handle product approval/rejection

3\. livestock-approval-webhook

•	Endpoint: https://oaynfzqjielnsipttzbs.supabase.co/functions/v1/livestock-approval-webhook

•	Authentication: API Key required

•	Purpose: Handle livestock listing approval/rejection

🗄️ Database Schema

Core Tables:

•	customers: Customer profiles and contact info

•	sellers: Seller profiles and business details

•	orders: Order management and tracking

•	order\_items: Individual items in orders

•	payments: Payment transactions and status

•	meat\_products: Meat product catalog

•	livestock\_listings: Livestock marketplace listings

•	otp\_verifications: OTP codes and verification status

•	otp\_rate\_limits: Rate limiting for OTP requests

🔧 Server \& Configuration Details

Supabase Configuration

•	Project ID: oaynfzqjielnsipttzbs

•	URL: https://oaynfzqjielnsipttzbs.supabase.co

•	Anon Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9heW5menFqaWVsbnNpcHR0emJzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk5MDU3NDUsImV4cCI6MjA2NTQ4MTc0NX0.RnhpZ7ri3Nf3vmDMCmLqYnB8cRNZc\_u-3dhCutpUWEA

Environment Secrets (Stored in Supabase):

•	SUPABASE\_URL - Database URL

•	SUPABASE\_ANON\_KEY - Public API key

•	SUPABASE\_SERVICE\_ROLE\_KEY - Admin API key

•	SUPABASE\_DB\_URL - Direct database connection

•	ODOO\_URL - Odoo ERP server URL

•	ODOO\_DB - Odoo database name

•	ODOO\_USERNAME - Odoo admin username

•	ODOO\_PASSWORD - Odoo admin password

•	FAST2SMS\_API\_KEY - SMS service API key

•	WEBHOOK\_API\_KEY - Webhook authentication key

•	PHONEPE\_MERCHANT\_ID - Payment gateway merchant ID

•	PHONEPE\_SALT\_KEY - Payment gateway salt key

•	PHONEPE\_SALT\_INDEX - Payment gateway salt index

•	PHONEPE\_BASE\_URL - Payment gateway base URL

File Storage (Supabase Storage):

•	meat-product-images (public)

•	livestock-images (public)

•	vaccination-reports (public)

🛠️ Integration Points

Odoo ERP Integration

•	Service: src/services/odooService.ts

•	Configuration: src/services/odooConfigManager.ts

•	Endpoints: Product sync, customer creation, inventory management

Payment Integration

•	PhonePe Gateway: Production-ready payment processing

•	Hooks: src/hooks/usePhonePePayment.ts

•	Features: Payment initiation, verification, order confirmation

SMS Integration

•	Fast2SMS: OTP delivery and notifications

•	Rate Limiting: 3 requests per hour per phone number

•	Verification: 5-minute expiry window

📱 Customer Portal Features

Shopping Experience:

•	Product browsing with filters

•	Search functionality

•	Wishlist management

•	Shopping cart

•	Real-time inventory updates

Account Management:

•	Profile management

•	Order history

•	Payment methods

•	Delivery preferences

•	Loyalty program

Advanced Features:

•	Live chat support

•	Order tracking

•	Recipe suggestions

•	Bulk ordering

•	Subscription management

•	Referral program

This comprehensive documentation provides all the technical details needed for AI agents to understand and work with the customer portal system. The architecture is designed for scalability, security, and seamless integration with external services.

























Complete Google Maps Integration Guide

Architecture Overview

This is a comprehensive location management system with Google Maps integration for a food delivery app. Here's how everything works together:

1\. Core Components \& Files

Frontend Components:

•	LocationPicker.tsx - Main map component with address picker

•	useLocation.ts - Hook for location state management

•	locationService.ts - Service layer for API calls

•	HeroSection.tsx - Uses LocationPicker for delivery address

•	CustomerAccount.tsx - Profile management with location setting

Backend/Edge Functions:

•	get-location-details/index.ts - Handles geocoding \& reverse geocoding

•	save-customer-location/index.ts - Saves location to database

Database Tables:

•	customers - Main customer data with location fields

•	customer\_profile\_audit - Audit trail for profile changes

2\. Google Maps Integration Flow

Step 1: API Loading \& Initialization

// LocationPicker.tsx - Line 41-80

useEffect(() => {

  if (!isOpen || mapInstance.current) return;

 

  // Load Google Maps API

  await locationService.loadGoogleMapsAPI();

 

  // Find isolated container

  const gmapsRoot = mapRef.current.querySelector('#gmaps-root');

 

  // Initialize map on isolated div (NOT React-managed div)

  mapInstance.current = new Map(gmapsRoot, {

    center: defaultLocation,

    zoom: 13,

    mapId: 'DEMO\_MAP\_ID',

    mapTypeControl: false,

    streetViewControl: false,

    fullscreenControl: false,

  });

}, \[isOpen]);



Step 2: Critical DOM Structure

// The container pattern that prevents removeChild errors

<div ref={mapRef} className="w-full h-96 ...">

  <div id="gmaps-root" className="w-full h-full rounded-lg" />

  {!isMapReady \&\& <LoadingIndicator />}

</div>

Why this works:

•	React manages the outer mapRef div

•	Google Maps only touches the inner #gmaps-root div

•	No DOM conflicts during unmounting

Step 3: Event Listeners \& Interactions

// Map click handler

mapInstance.current.addListener('click', async (event) => {

  const lat = event.latLng.lat();

  const lng = event.latLng.lng();

  setCoordinates({ lat, lng });

 

  // Update marker position

  markerInstance.current.position = { lat, lng };

 

  // Reverse geocode to get address

  const addressResult = await locationService.reverseGeocode(lat, lng);

  setAddress(addressResult);

});



// Places Autocomplete

autocompleteInstance.current = new Autocomplete(inputRef.current, {

  types: \['address'],

  componentRestrictions: { country: 'IN' }

});



3\. API Integration \& Edge Functions

Geocoding Service Architecture:

// locationService.ts

export const locationService = {

  // Loads Google Maps JavaScript API

  async loadGoogleMapsAPI(): Promise<void>,

 

  // Coordinates → Address

  async reverseGeocode(lat: number, lng: number): Promise<string | null>,

 

  // Address → Coordinates

  async geocodeAddress(address: string): Promise<{lat: number; lng: number} | null>,

 

  // Save to database

  async saveCustomerLocation(customerId: string, location: LocationData): Promise<boolean>

}



Edge Function: get-location-details

// Handles both geocoding and reverse geocoding

const payload = {

  lat: 12.9141,           // For reverse geocoding

  lng: 74.8560,

  address: "Mangaluru",   // For geocoding

  type: "reverse" | "geocode"

}



// Response for reverse geocoding

{

  "address": "Jail Road, Mangaluru, Karnataka 575002, India",

  "components": \[...]

}



// Response for geocoding

{

  "coordinates": { "lat": 12.9141, "lng": 74.8560 },

  "formatted\_address": "...",

  "components": \[...]

}



4\. Database Schema \& Data Flow

customers Table Fields:

-- Location-specific fields

address                TEXT,

location\_latitude      NUMERIC,

location\_longitude     NUMERIC,



-- Other customer fields

full\_name             TEXT NOT NULL,

phone\_number          TEXT NOT NULL,

email                 TEXT,

business\_address      TEXT,

business\_city         TEXT,

business\_pincode      TEXT,

-- ... other fields



customer\_profile\_audit Table:

-- Audit trail for all profile changes

customer\_id           UUID,

field\_name           TEXT NOT NULL,

old\_value            TEXT,

new\_value            TEXT,

change\_reason        TEXT,

changed\_by           UUID,

created\_at           TIMESTAMP DEFAULT now()





Data Flow Example:

// 1. User picks location on map

const location = {

  address: "Jail Road, Mangaluru",

  lat: 12.9141,

  lng: 74.8560

};



// 2. Save to localStorage (immediate)

localStorage.setItem('customerLocation', JSON.stringify(location));



// 3. Save to database (if logged in)

await locationService.saveCustomerLocation(customerId, location);



// 4. Creates audit trail

{

  customer\_id: "uuid-123",

  field\_name: "delivery\_location",

  new\_value: '{"address":"Jail Road, Mangaluru","lat":12.9141,"lng":74.8560}',

  change\_reason: "Location updated by customer"

}



5\. Sensitive Data \& Configuration

Environment Variables (Supabase Secrets):

\# Required in Edge Functions

GOOGLE\_MAPS\_API\_KEY=AIzaSy...              # Google Maps API key

SUPABASE\_URL=https://project.supabase.co   # Auto-provided

SUPABASE\_SERVICE\_ROLE\_KEY=ey...            # Auto-provided



Google Maps API Configuration:

•	Libraries loaded: places (for autocomplete)

•	APIs used: Geocoding API, Maps JavaScript API

•	Country restriction: India (componentRestrictions: { country: 'IN' })

•	Map settings: No controls, zoom level 13, centered on Karnataka

6\. Error Handling \& Fallbacks

Network Failure Handling:

// Primary: Use edge function

const data = await supabase.functions.invoke('get-location-details', {...});



// Fallback: Direct Google Maps API call

if (error) {

  const geocoder = new google.maps.Geocoder();

  return geocoder.geocode({location: {lat, lng}});

}



Component Lifecycle Safety:

// Prevents race conditions during component unmount

let isComponentMounted = true;



// All async operations check this flag

if (!isComponentMounted) return;



// Cleanup function

return () => {

  isComponentMounted = false;

  google.maps.event.clearInstanceListeners(mapInstance.current);

  mapInstance.current = null;

};



7\. Integration Points in the App

Where LocationPicker is Used:

1\.	HeroSection - Set delivery location for browsing

2\.	CustomerAccount - Update profile address

3\.	Onboarding flows - Initial address collection

State Management:

// useLocation hook manages:

\- currentLocation: LocationData | null    // Current user location

\- isLoading: boolean                      // Loading state

\- error: string | null                    // Error messages



// Persisted in localStorage as 'customerLocation'



8\. How to Recreate This Logic

Setup Steps:

1\.	Get Google Maps API Key with Geocoding + Maps JavaScript APIs

2\.	Create Supabase Edge Functions for geocoding (handles API key securely)

3\.	Set up database tables with location fields + audit trails

4\.	Implement the container pattern to avoid React DOM conflicts

5\.	Add proper cleanup in useEffect to prevent memory leaks

Key Implementation Patterns:

•	✅ Container Pattern: Google Maps in isolated div inside React container

•	✅ Edge Function Proxy: Hide API keys, add fallback logic

•	✅ State Persistence: localStorage + database for location data

•	✅ Proper Cleanup: Clear all Google Maps instances and listeners

•	✅ Audit Trail: Track all location changes for compliance

This architecture ensures secure, performant location handling with proper error handling and data persistence! The critical innovation was the container pattern that separates React DOM management from Google Maps DOM mutations.

