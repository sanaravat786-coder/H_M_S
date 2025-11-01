-- =================================================================
-- Final Master Migration Script for Hostel Management System
-- Version: 4.0
-- Date: 2025-07-26
-- Description: This is a complete, idempotent script that resets and
--              rebuilds the entire database schema, functions, and
--              policies. It is designed to be run safely on a new
--              or previously failed database setup.
-- =================================================================

-- Step 1: Drop existing objects in reverse order of dependency to ensure a clean slate.
-- Using CASCADE to handle all dependencies automatically.
DROP FUNCTION IF EXISTS public.get_recent_activity() CASCADE;
DROP FUNCTION IF EXISTS public.resolve_complaint(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.add_complaint(text, text, uuid) CASCADE;
DROP FUNCTION IF EXISTS public.checkout_visitor(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.log_visitor(text, text, uuid, text) CASCADE;
DROP FUNCTION IF EXISTS public.record_payment(uuid, numeric, text) CASCADE;
DROP FUNCTION IF EXISTS public.add_room(text, text, text, integer) CASCADE;
DROP FUNCTION IF EXISTS public.update_student_details_and_allocate_room(uuid, text, text, date, text, uuid) CASCADE;
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users CASCADE;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.get_my_claim(text) CASCADE;
DROP FUNCTION IF EXISTS public.get_my_role() CASCADE;

DROP TABLE IF EXISTS public.payments CASCADE;
DROP TABLE IF EXISTS public.fees CASCADE;
DROP TABLE IF EXISTS public.complaints CASCADE;
DROP TABLE IF EXISTS public.visitors CASCADE;
DROP TABLE IF EXISTS public.notices CASCADE;
DROP TABLE IF EXISTS public.allocations CASCADE;
DROP TABLE IF EXISTS public.students CASCADE;
DROP TABLE IF EXISTS public.rooms CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

-- Step 2: Create helper functions FIRST. This resolves the primary error.
CREATE OR REPLACE FUNCTION public.get_my_claim(claim TEXT)
RETURNS JSONB
LANGUAGE sql STABLE
AS $$
  SELECT COALESCE(NULLIF(current_setting('request.jwt.claims', true), '')::JSONB ->> claim, NULL)::JSONB;
$$;

CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS TEXT
LANGUAGE sql STABLE
AS $$
  SELECT public.get_my_claim('user_role')::TEXT;
$$;

-- Step 3: Create tables in the correct order of dependency.
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('Admin', 'Warden', 'Student')),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_no TEXT NOT NULL UNIQUE,
    block TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('Single', 'Double', 'Triple')),
    capacity INT NOT NULL,
    status TEXT NOT NULL DEFAULT 'Available' CHECK (status IN ('Available', 'Occupied', 'Maintenance')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    course TEXT,
    contact TEXT,
    joining_date DATE,
    status TEXT CHECK (status IN ('Active', 'Inactive')),
    room_id UUID REFERENCES public.rooms(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.allocations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    date_allocated DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.fees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    total_amount NUMERIC(10, 2) NOT NULL,
    due_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'Paid', 'Overdue')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fee_id UUID NOT NULL REFERENCES public.fees(id) ON DELETE CASCADE,
    amount NUMERIC(10, 2) NOT NULL,
    payment_method TEXT NOT NULL,
    payment_date TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.visitors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    contact TEXT,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    purpose TEXT,
    in_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    out_time TIMESTAMPTZ
);

CREATE TABLE public.complaints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'Pending' CHECK (status IN ('Pending', 'In Progress', 'Resolved')),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE public.notices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Step 4: Create the trigger function to link auth.users to public tables.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  -- Create a profile
  INSERT INTO public.profiles (id, full_name, role)
  VALUES (NEW.id, NEW.raw_user_meta_data ->> 'full_name', NEW.raw_user_meta_data ->> 'role');

  -- If the role is Student, also create a student record
  IF (NEW.raw_user_meta_data ->> 'role') = 'Student' THEN
    INSERT INTO public.students (user_id, name, status)
    VALUES (NEW.id, NEW.raw_user_meta_data ->> 'full_name', 'Active');
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create the trigger itself.
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Step 5: Enable Row Level Security on all tables.
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visitors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.complaints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notices ENABLE ROW LEVEL SECURITY;

-- Step 6: Create RLS policies for data access.
-- Profiles Table
CREATE POLICY "Allow individual read access" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Allow individual update access" ON public.profiles FOR UPDATE USING (auth.uid() = id);
CREATE POLICY "Admins can see all profiles" ON public.profiles FOR SELECT TO authenticated USING (get_my_role() = 'Admin');

-- Students Table
CREATE POLICY "Admin/Warden can manage students" ON public.students FOR ALL USING (get_my_role() IN ('Admin', 'Warden'));
CREATE POLICY "Students can view their own record" ON public.students FOR SELECT USING (user_id = auth.uid());

-- Rooms Table
CREATE POLICY "Allow all authenticated users to read rooms" ON public.rooms FOR SELECT USING (true);
CREATE POLICY "Admin/Warden can manage rooms" ON public.rooms FOR ALL USING (get_my_role() IN ('Admin', 'Warden'));

-- Fees & Payments Table
CREATE POLICY "Admin/Warden can manage fees" ON public.fees FOR ALL USING (get_my_role() IN ('Admin', 'Warden'));
CREATE POLICY "Students can view their own fees" ON public.fees FOR SELECT USING (EXISTS (SELECT 1 FROM students WHERE students.id = fees.student_id AND students.user_id = auth.uid()));
CREATE POLICY "Admin/Warden can manage payments" ON public.payments FOR ALL USING (get_my_role() IN ('Admin', 'Warden'));
CREATE POLICY "Students can view their own payments" ON public.payments FOR SELECT USING (EXISTS (SELECT 1 FROM fees f JOIN students s ON f.student_id = s.id WHERE f.id = payments.fee_id AND s.user_id = auth.uid()));

-- Complaints Table
CREATE POLICY "Admin/Warden can manage complaints" ON public.complaints FOR ALL USING (get_my_role() IN ('Admin', 'Warden'));
CREATE POLICY "Students can manage their own complaints" ON public.complaints FOR ALL USING (EXISTS (SELECT 1 FROM students WHERE students.id = complaints.student_id AND students.user_id = auth.uid()));

-- Visitors Table
CREATE POLICY "Admin/Warden can manage visitors" ON public.visitors FOR ALL USING (get_my_role() IN ('Admin', 'Warden'));

-- Notices Table
CREATE POLICY "Allow all authenticated to read notices" ON public.notices FOR SELECT USING (true);
CREATE POLICY "Admins can manage notices" ON public.notices FOR ALL USING (get_my_role() = 'Admin');

-- Allocations Table
CREATE POLICY "Admin/Warden can manage allocations" ON public.allocations FOR ALL USING (get_my_role() IN ('Admin', 'Warden'));

-- Step 7: Create RPC functions for business logic.
CREATE OR REPLACE FUNCTION public.update_student_details_and_allocate_room(
    p_user_id UUID,
    p_course TEXT,
    p_contact TEXT,
    p_joining_date DATE,
    p_status TEXT,
    p_room_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    v_student_id UUID;
BEGIN
    -- Find the student_id associated with the user_id
    SELECT id INTO v_student_id FROM students WHERE user_id = p_user_id;

    -- Update the student record
    UPDATE students
    SET
        course = p_course,
        contact = p_contact,
        joining_date = p_joining_date,
        status = p_status,
        room_id = p_room_id
    WHERE id = v_student_id;

    -- If a room was assigned, update its status and create an allocation record
    IF p_room_id IS NOT NULL THEN
        UPDATE rooms SET status = 'Occupied' WHERE id = p_room_id;
        INSERT INTO allocations (student_id, room_id) VALUES (v_student_id, p_room_id);
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.add_room(
    p_room_no TEXT,
    p_block TEXT,
    p_type TEXT,
    p_capacity INT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    INSERT INTO rooms (room_no, block, type, capacity)
    VALUES (p_room_no, p_block, p_type, p_capacity);
END;
$$;

CREATE OR REPLACE FUNCTION public.record_payment(
    p_fee_id UUID,
    p_amount NUMERIC,
    p_payment_method TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    v_total_paid NUMERIC;
    v_total_amount NUMERIC;
BEGIN
    -- Insert the new payment
    INSERT INTO payments (fee_id, amount, payment_method)
    VALUES (p_fee_id, p_amount, p_payment_method);

    -- Recalculate total paid for the fee
    SELECT SUM(amount) INTO v_total_paid FROM payments WHERE fee_id = p_fee_id;
    SELECT total_amount INTO v_total_amount FROM fees WHERE id = p_fee_id;

    -- Update the fee status if fully paid
    IF v_total_paid >= v_total_amount THEN
        UPDATE fees SET status = 'Paid' WHERE id = p_fee_id;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.log_visitor(
    p_name TEXT,
    p_contact TEXT,
    p_student_id UUID,
    p_purpose TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    INSERT INTO visitors (name, contact, student_id, purpose)
    VALUES (p_name, p_contact, p_student_id, p_purpose);
END;
$$;

CREATE OR REPLACE FUNCTION public.checkout_visitor(p_visitor_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    UPDATE visitors SET out_time = NOW() WHERE id = p_visitor_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.add_complaint(
    p_title TEXT,
    p_description TEXT,
    p_student_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
    v_room_id UUID;
BEGIN
    -- Get the student's room
    SELECT room_id INTO v_room_id FROM students WHERE id = p_student_id;
    
    IF v_room_id IS NULL THEN
        RAISE EXCEPTION 'Student is not assigned to a room.';
    END IF;

    INSERT INTO complaints (student_id, room_id, title, description)
    VALUES (p_student_id, v_room_id, p_title, p_description);
END;
$$;

CREATE OR REPLACE FUNCTION public.resolve_complaint(p_complaint_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    UPDATE complaints SET status = 'Resolved' WHERE id = p_complaint_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_recent_activity()
RETURNS TABLE(id UUID, text TEXT, icon TEXT, created_at TIMESTAMPTZ)
LANGUAGE sql
STABLE
AS $$
    (SELECT id, 'New student ' || name || ' joined.', 'user-plus' as icon, created_at FROM students ORDER BY created_at DESC LIMIT 2)
    UNION ALL
    (SELECT id, 'Visitor ' || name || ' logged.', 'user-check' as icon, in_time as created_at FROM visitors ORDER BY in_time DESC LIMIT 2)
    UNION ALL
    (SELECT id, 'Complaint about "' || title || '" was raised.', 'shield-alert' as icon, created_at FROM complaints ORDER BY created_at DESC LIMIT 2)
    UNION ALL
    (SELECT id, 'New notice: "' || title || '" posted.', 'megaphone' as icon, created_at FROM notices ORDER BY created_at DESC LIMIT 2)
    ORDER BY created_at DESC
    LIMIT 5;
$$;
