-- ============================================================================
-- TRUST & QUALITY REVIEW SYSTEM MIGRATION
-- ============================================================================

-- 1. Create the reviews table
CREATE TABLE IF NOT EXISTS reviews (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    customer_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    store_id UUID NOT NULL REFERENCES stores(id) ON DELETE RESTRICT,
    driver_id UUID REFERENCES drivers(id) ON DELETE SET NULL,
    rating INT NOT NULL CHECK (rating >= 1 AND rating <= 5),
    comment TEXT,
    image_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_order_review UNIQUE (order_id) -- One review per order
);

CREATE INDEX IF NOT EXISTS idx_reviews_store ON reviews(store_id);
CREATE INDEX IF NOT EXISTS idx_reviews_driver ON reviews(driver_id);
CREATE INDEX IF NOT EXISTS idx_reviews_customer ON reviews(customer_id);

-- 2. Add triggers for updated_at (assuming set_updated_at_column already exists from schema.sql)
CREATE TRIGGER trg_reviews_updated_at
BEFORE UPDATE ON reviews
FOR EACH ROW EXECUTE FUNCTION set_updated_at_column();

-- 3. Implementation of aggregate rating update logic
-- We'll use a trigger to keep Store and Driver ratings in sync

CREATE OR REPLACE FUNCTION update_store_rating_func()
RETURNS TRIGGER AS $BODY$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        UPDATE stores 
        SET 
            rating = (SELECT COALESCE(AVG(rating), 5.00) FROM reviews WHERE store_id = OLD.store_id),
            total_ratings = (SELECT COUNT(*) FROM reviews WHERE store_id = OLD.store_id)
        WHERE id = OLD.store_id;
    ELSE
        UPDATE stores 
        SET 
            rating = (SELECT COALESCE(AVG(rating), 5.00) FROM reviews WHERE store_id = NEW.store_id),
            total_ratings = (SELECT COUNT(*) FROM reviews WHERE store_id = NEW.store_id)
        WHERE id = NEW.store_id;
    END IF;
    RETURN NULL;
END;
$BODY$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_store_rating
AFTER INSERT OR UPDATE OR DELETE ON reviews
FOR EACH ROW EXECUTE FUNCTION update_store_rating_func();

CREATE OR REPLACE FUNCTION update_driver_rating_func()
RETURNS TRIGGER AS $BODY$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        IF OLD.driver_id IS NOT NULL THEN
            UPDATE drivers 
            SET 
                rating = (SELECT COALESCE(AVG(rating), 5.00) FROM reviews WHERE driver_id = OLD.driver_id)
            WHERE id = OLD.driver_id;
        END IF;
    ELSE
        IF NEW.driver_id IS NOT NULL THEN
            UPDATE drivers 
            SET 
                rating = (SELECT COALESCE(AVG(rating), 5.00) FROM reviews WHERE driver_id = NEW.driver_id)
            WHERE id = NEW.driver_id;
        END IF;
    END IF;
    RETURN NULL;
END;
$BODY$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_driver_rating
AFTER INSERT OR UPDATE OR DELETE ON reviews
FOR EACH ROW EXECUTE FUNCTION update_driver_rating_func();
