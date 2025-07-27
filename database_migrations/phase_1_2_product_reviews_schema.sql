-- Phase 1.2 Product Reviews & Ratings Database Schema
-- 
-- This script creates the necessary database tables and policies for the
-- Product Reviews & Ratings feature without modifying existing tables.
-- 
-- Key principles:
-- - No modifications to existing tables
-- - Verified purchase requirement (linked to orders)
-- - Admin moderation capabilities
-- - Comprehensive review analytics

-- ============================================================================
-- PRODUCT REVIEWS TABLE
-- ============================================================================

-- Create product reviews table with verified purchase tracking
CREATE TABLE IF NOT EXISTS product_reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id UUID REFERENCES meat_products(id) ON DELETE CASCADE,
  customer_id UUID REFERENCES customers(id) ON DELETE CASCADE,
  order_id UUID REFERENCES orders(id) ON DELETE SET NULL,
  order_item_id UUID REFERENCES order_items(id) ON DELETE SET NULL,
  
  -- Review content
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  review_title TEXT,
  review_text TEXT,
  
  -- Verification and moderation
  is_verified_purchase BOOLEAN DEFAULT false,
  moderation_status TEXT DEFAULT 'pending' CHECK (moderation_status IN ('pending', 'approved', 'rejected')),
  moderation_reason TEXT,
  moderated_by UUID REFERENCES auth.users(id),
  moderated_at TIMESTAMP WITH TIME ZONE,
  
  -- Engagement metrics
  helpful_count INTEGER DEFAULT 0,
  unhelpful_count INTEGER DEFAULT 0,
  
  -- Media attachments (future enhancement)
  review_images JSONB DEFAULT '[]'::jsonb,
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Constraints
  UNIQUE(product_id, customer_id, order_id) -- One review per product per order
);

-- Create indexes for efficient querying
CREATE INDEX IF NOT EXISTS idx_product_reviews_product_id ON product_reviews(product_id);
CREATE INDEX IF NOT EXISTS idx_product_reviews_customer_id ON product_reviews(customer_id);
CREATE INDEX IF NOT EXISTS idx_product_reviews_rating ON product_reviews(rating);
CREATE INDEX IF NOT EXISTS idx_product_reviews_moderation_status ON product_reviews(moderation_status);
CREATE INDEX IF NOT EXISTS idx_product_reviews_created_at ON product_reviews(created_at);
CREATE INDEX IF NOT EXISTS idx_product_reviews_verified_purchase ON product_reviews(is_verified_purchase);

-- ============================================================================
-- REVIEW HELPFULNESS TRACKING
-- ============================================================================

-- Track which customers found reviews helpful
CREATE TABLE IF NOT EXISTS review_helpfulness (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id UUID REFERENCES product_reviews(id) ON DELETE CASCADE,
  customer_id UUID REFERENCES customers(id) ON DELETE CASCADE,
  is_helpful BOOLEAN NOT NULL, -- true = helpful, false = not helpful
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Constraints
  UNIQUE(review_id, customer_id) -- One vote per customer per review
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_review_helpfulness_review_id ON review_helpfulness(review_id);
CREATE INDEX IF NOT EXISTS idx_review_helpfulness_customer_id ON review_helpfulness(customer_id);

-- ============================================================================
-- REVIEW ANALYTICS TABLE
-- ============================================================================

-- Pre-computed review statistics for performance
CREATE TABLE IF NOT EXISTS product_review_stats (
  product_id UUID PRIMARY KEY REFERENCES meat_products(id) ON DELETE CASCADE,
  
  -- Rating statistics
  total_reviews INTEGER DEFAULT 0,
  average_rating DECIMAL(3,2) DEFAULT 0.00,
  rating_1_count INTEGER DEFAULT 0,
  rating_2_count INTEGER DEFAULT 0,
  rating_3_count INTEGER DEFAULT 0,
  rating_4_count INTEGER DEFAULT 0,
  rating_5_count INTEGER DEFAULT 0,
  
  -- Verification statistics
  verified_reviews_count INTEGER DEFAULT 0,
  verified_average_rating DECIMAL(3,2) DEFAULT 0.00,
  
  -- Timestamps
  last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- RLS POLICIES FOR PRODUCT REVIEWS
-- ============================================================================

-- Enable RLS on all review tables
ALTER TABLE product_reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE review_helpfulness ENABLE ROW LEVEL SECURITY;
ALTER TABLE product_review_stats ENABLE ROW LEVEL SECURITY;

-- Product Reviews Policies
CREATE POLICY "Customers can create reviews for their purchases" ON product_reviews
FOR INSERT WITH CHECK (
  customer_id IN (SELECT id FROM customers WHERE user_id = auth.uid())
  AND (
    order_id IS NULL OR 
    order_id IN (
      SELECT id FROM orders WHERE customer_id IN (
        SELECT id FROM customers WHERE user_id = auth.uid()
      )
    )
  )
);

CREATE POLICY "Anyone can view approved reviews" ON product_reviews
FOR SELECT USING (moderation_status = 'approved');

CREATE POLICY "Customers can view their own reviews" ON product_reviews
FOR SELECT USING (
  customer_id IN (SELECT id FROM customers WHERE user_id = auth.uid())
);

CREATE POLICY "Customers can update their own pending reviews" ON product_reviews
FOR UPDATE USING (
  customer_id IN (SELECT id FROM customers WHERE user_id = auth.uid())
  AND moderation_status = 'pending'
);

CREATE POLICY "Service role can manage all reviews" ON product_reviews
FOR ALL USING (auth.role() = 'service_role');

-- Review Helpfulness Policies
CREATE POLICY "Customers can vote on review helpfulness" ON review_helpfulness
FOR INSERT WITH CHECK (
  customer_id IN (SELECT id FROM customers WHERE user_id = auth.uid())
);

CREATE POLICY "Anyone can view helpfulness votes" ON review_helpfulness
FOR SELECT USING (true);

CREATE POLICY "Customers can update their own votes" ON review_helpfulness
FOR UPDATE USING (
  customer_id IN (SELECT id FROM customers WHERE user_id = auth.uid())
);

-- Review Stats Policies
CREATE POLICY "Anyone can view review statistics" ON product_review_stats
FOR SELECT USING (true);

CREATE POLICY "Service role can manage review statistics" ON product_review_stats
FOR ALL USING (auth.role() = 'service_role');

-- ============================================================================
-- UTILITY FUNCTIONS FOR REVIEW MANAGEMENT
-- ============================================================================

-- Function to update review statistics
CREATE OR REPLACE FUNCTION update_product_review_stats(target_product_id UUID)
RETURNS VOID AS $$
DECLARE
  stats_record RECORD;
BEGIN
  -- Calculate review statistics
  SELECT 
    COUNT(*) as total_reviews,
    COALESCE(AVG(rating), 0) as average_rating,
    COUNT(CASE WHEN rating = 1 THEN 1 END) as rating_1_count,
    COUNT(CASE WHEN rating = 2 THEN 1 END) as rating_2_count,
    COUNT(CASE WHEN rating = 3 THEN 1 END) as rating_3_count,
    COUNT(CASE WHEN rating = 4 THEN 1 END) as rating_4_count,
    COUNT(CASE WHEN rating = 5 THEN 1 END) as rating_5_count,
    COUNT(CASE WHEN is_verified_purchase = true THEN 1 END) as verified_reviews_count,
    COALESCE(AVG(CASE WHEN is_verified_purchase = true THEN rating END), 0) as verified_average_rating
  INTO stats_record
  FROM product_reviews 
  WHERE product_id = target_product_id 
    AND moderation_status = 'approved';

  -- Upsert statistics
  INSERT INTO product_review_stats (
    product_id, total_reviews, average_rating,
    rating_1_count, rating_2_count, rating_3_count, rating_4_count, rating_5_count,
    verified_reviews_count, verified_average_rating, last_updated
  ) VALUES (
    target_product_id, stats_record.total_reviews, stats_record.average_rating,
    stats_record.rating_1_count, stats_record.rating_2_count, stats_record.rating_3_count,
    stats_record.rating_4_count, stats_record.rating_5_count,
    stats_record.verified_reviews_count, stats_record.verified_average_rating, NOW()
  )
  ON CONFLICT (product_id) DO UPDATE SET
    total_reviews = EXCLUDED.total_reviews,
    average_rating = EXCLUDED.average_rating,
    rating_1_count = EXCLUDED.rating_1_count,
    rating_2_count = EXCLUDED.rating_2_count,
    rating_3_count = EXCLUDED.rating_3_count,
    rating_4_count = EXCLUDED.rating_4_count,
    rating_5_count = EXCLUDED.rating_5_count,
    verified_reviews_count = EXCLUDED.verified_reviews_count,
    verified_average_rating = EXCLUDED.verified_average_rating,
    last_updated = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update review helpfulness counts
CREATE OR REPLACE FUNCTION update_review_helpfulness_counts(target_review_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE product_reviews SET
    helpful_count = (
      SELECT COUNT(*) FROM review_helpfulness 
      WHERE review_id = target_review_id AND is_helpful = true
    ),
    unhelpful_count = (
      SELECT COUNT(*) FROM review_helpfulness 
      WHERE review_id = target_review_id AND is_helpful = false
    ),
    updated_at = NOW()
  WHERE id = target_review_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to verify purchase for review
CREATE OR REPLACE FUNCTION verify_purchase_for_review(
  target_customer_id UUID,
  target_product_id UUID,
  target_order_id UUID DEFAULT NULL
)
RETURNS BOOLEAN AS $$
DECLARE
  purchase_exists BOOLEAN := false;
BEGIN
  -- Check if customer purchased this product
  SELECT EXISTS(
    SELECT 1 FROM order_items oi
    JOIN orders o ON oi.order_id = o.id
    WHERE o.customer_id = target_customer_id
      AND oi.product_id = target_product_id
      AND o.order_status IN ('delivered', 'completed')
      AND (target_order_id IS NULL OR o.id = target_order_id)
  ) INTO purchase_exists;
  
  RETURN purchase_exists;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- TRIGGERS FOR AUTOMATIC UPDATES
-- ============================================================================

-- Trigger to update review statistics when reviews change
CREATE OR REPLACE FUNCTION trigger_update_review_stats()
RETURNS TRIGGER AS $$
BEGIN
  -- Update stats for the affected product
  IF TG_OP = 'DELETE' THEN
    PERFORM update_product_review_stats(OLD.product_id);
    RETURN OLD;
  ELSE
    PERFORM update_product_review_stats(NEW.product_id);
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_product_review_stats_update ON product_reviews;
CREATE TRIGGER trigger_product_review_stats_update
  AFTER INSERT OR UPDATE OR DELETE ON product_reviews
  FOR EACH ROW EXECUTE FUNCTION trigger_update_review_stats();

-- Trigger to update helpfulness counts
CREATE OR REPLACE FUNCTION trigger_update_helpfulness_counts()
RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'DELETE' THEN
    PERFORM update_review_helpfulness_counts(OLD.review_id);
    RETURN OLD;
  ELSE
    PERFORM update_review_helpfulness_counts(NEW.review_id);
    RETURN NEW;
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_review_helpfulness_update ON review_helpfulness;
CREATE TRIGGER trigger_review_helpfulness_update
  AFTER INSERT OR UPDATE OR DELETE ON review_helpfulness
  FOR EACH ROW EXECUTE FUNCTION trigger_update_helpfulness_counts();

-- ============================================================================
-- ADMIN FUNCTIONS FOR REVIEW MODERATION
-- ============================================================================

-- Function to approve a review
CREATE OR REPLACE FUNCTION approve_review(
  target_review_id UUID,
  moderator_id UUID
)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE product_reviews SET
    moderation_status = 'approved',
    moderated_by = moderator_id,
    moderated_at = NOW(),
    moderation_reason = NULL,
    updated_at = NOW()
  WHERE id = target_review_id;
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to reject a review
CREATE OR REPLACE FUNCTION reject_review(
  target_review_id UUID,
  moderator_id UUID,
  rejection_reason TEXT
)
RETURNS BOOLEAN AS $$
BEGIN
  UPDATE product_reviews SET
    moderation_status = 'rejected',
    moderated_by = moderator_id,
    moderated_at = NOW(),
    moderation_reason = rejection_reason,
    updated_at = NOW()
  WHERE id = target_review_id;
  
  RETURN FOUND;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- VERIFICATION QUERIES
-- ============================================================================

-- Verify tables were created successfully
DO $$
BEGIN
  -- Check if all tables exist
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'product_reviews') THEN
    RAISE EXCEPTION 'product_reviews table was not created';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'review_helpfulness') THEN
    RAISE EXCEPTION 'review_helpfulness table was not created';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'product_review_stats') THEN
    RAISE EXCEPTION 'product_review_stats table was not created';
  END IF;
  
  RAISE NOTICE 'All Phase 1.2 Product Reviews tables created successfully!';
  
  -- Show table statistics
  RAISE NOTICE 'Product Reviews schema ready for implementation';
END $$;
