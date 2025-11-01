-- Drop existing objects in reverse order of dependency, using CASCADE
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user() CASCADE;
DROP FUNCTION IF EXISTS public.get_recent_activity() CASCADE;
DROP FUNCTION IF EXISTS public.add_room(text, text, text, integer) CASCADE;
DROP FUNCTION IF EXISTS public.log_visitor(text, text, uuid, text) CASCADE;
DROP FUNCTION IF EXISTS public.checkout_visitor(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.add_complaint(uuid, text, text) CASCADE;
DROP FUNCTION IF EXISTS public.resolve_complaint(uuid) CASCADE;
DROP FUNCTION IF EXISTS public.record_payment(uuid, numeric, text) CASCADE;
DROP FUNCTION IF EXISTS public.update_student_details_and_allocate_room(uuid, text, text, date, text, uuid) CASCADE;

DROP TABLE IF EXISTS public.activity_log CASCADE;
DROP TABLE IF EXISTS public.payments CASCADE;
DROP TABLE IF EXISTS public.fees CASCADE;
DROP TABLE IF EXISTS public.visitors CASCADE;
DROP TABLE IF EXISTS public.complaints CASCADE;
DROP TABLE IF EXISTS public.notices CASCADE;
DROP TABLE IF EXISTS public.allocations CASCADE;
DROP TABLE IF EXISTS public.students CASCADE;
DROP TABLE IF EXISTS public.rooms CASCADE;
DROP TABLE IF EXISTS public.profiles CASCADE;

DROP TYPE IF EXISTS public.user_role CASCADE;
DROP TYPE IF EXISTS public.room_status CASCADE;
DROP TYPE IF EXISTS public.room_type CASCADE;
DROP TYPE IF EXISTS public.student_status CASCADE;
DROP TYPE IF EXISTS public.fee_status CASCADE;
DROP TYPE IF EXISTS public.complaint_status CASCADE;

-- =================================================================
-- Step 1: Create ENUM Types
-- =================================================================
CREATE TYPE public.user_role AS ENUM ('Admin', 'Warden', 'Student');
CREATE TYPE public.room_status AS ENUM ('Available', 'Occupied', 'Maintenance');
CREATE TYPE public.room_type AS ENUM ('Single', 'Double', 'Triple');
CREATE TYPE public.student_status AS ENUM ('Active', 'Inactive');
CREATE TYPE public.fee_status AS ENUM ('Paid', 'Pending', 'Overdue');
CREATE TYPE public.complaint_status AS ENUM ('Pending', 'In Progress', 'Resolved');

-- =================================================================
-- Step 2: Create Tables
-- =================================================================

-- Profiles Table (linked to auth.users)
CREATE TABLE public.profiles (
    id uuid NOT NULL PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name text,
    role user_role NOT NULL DEFAULT 'Student'::user_role
);
COMMENT ON TABLE public.profiles IS 'Stores public-facing profile data for each user.';

-- Rooms Table
CREATE TABLE public.rooms (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    room_no text NOT NULL UNIQUE,
    block text NOT NULL,
    type room_type NOT NULL,
    capacity integer NOT NULL,
    status room_status NOT NULL DEFAULT 'Available'::room_status
);
COMMENT ON TABLE public.rooms IS 'Manages all hostel rooms and their status.';

-- Students Table (extends profiles for student-specific data)
CREATE TABLE public.students (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    profile_id uuid NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    name text,
    course text,
    contact text,
    joining_date date,
    room_id uuid REFERENCES public.rooms(id) ON DELETE SET NULL,
    status student_status NOT NULL DEFAULT 'Active'::student_status
);
COMMENT ON TABLE public.students IS 'Stores detailed information about each student.';

-- Allocations Table (history of room assignments)
CREATE TABLE public.allocations (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    room_id uuid NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    date_allocated date NOT NULL DEFAULT now(),
    date_vacated date
);
COMMENT ON TABLE public.allocations IS 'Tracks room allocation history for students.';

-- Fees Table
CREATE TABLE public.fees (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    total_amount numeric(10, 2) NOT NULL,
    due_date date NOT NULL,
    status fee_status NOT NULL DEFAULT 'Pending'::fee_status,
    created_at timestamp with time zone DEFAULT now()
);
COMMENT ON TABLE public.fees IS 'Manages fee invoices for students.';

-- Payments Table
CREATE TABLE public.payments (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    fee_id uuid NOT NULL REFERENCES public.fees(id) ON DELETE CASCADE,
    amount numeric(10, 2) NOT NULL,
    payment_method text NOT NULL,
    payment_date timestamp with time zone DEFAULT now()
);
COMMENT ON TABLE public.payments IS 'Records individual payment transactions against fees.';

-- Visitors Table
CREATE TABLE public.visitors (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    contact text,
    student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    purpose text,
    in_time timestamp with time zone NOT NULL DEFAULT now(),
    out_time timestamp with time zone
);
COMMENT ON TABLE public.visitors IS 'Logs visitor entries and exits.';

-- Complaints Table
CREATE TABLE public.complaints (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    room_id uuid REFERENCES public.rooms(id) ON DELETE SET NULL,
    title text NOT NULL,
    description text,
    status complaint_status NOT NULL DEFAULT 'Pending'::complaint_status,
    created_at timestamp with time zone DEFAULT now()
);
COMMENT ON TABLE public.complaints IS 'Tracks student complaints about maintenance or other issues.';

-- Notices Table
CREATE TABLE public.notices (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title text NOT NULL,
    message text,
    created_at timestamp with time zone DEFAULT now()
);
COMMENT ON TABLE public.notices IS 'Stores announcements and notices for students.';

-- Activity Log Table
CREATE TABLE public.activity_log (
    id bigint GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    created_at timestamp with time zone DEFAULT now(),
    text text,
    icon text
);
COMMENT ON TABLE public.activity_log IS 'Logs key system events for the dashboard activity feed.';

-- =================================================================
-- Step 3: Enable Row Level Security (RLS)
-- =================================================================
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visitors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.complaints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_log ENABLE ROW LEVEL SECURITY;

-- =================================================================
-- Step 4: Create RLS Policies
-- =================================================================

-- Profiles: Users can see their own profile. Admins/Wardens can see all.
CREATE POLICY "Allow individual read access" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Allow admin/warden full access" ON public.profiles FOR ALL USING (get_my_claim('role')::text IN ('Admin', 'Warden')) WITH CHECK (get_my_claim('role')::text IN ('Admin', 'Warden'));

-- Students: Admins/Wardens can see all. Students can see their own record.
CREATE POLICY "Allow admin/warden full access" ON public.students FOR ALL USING (get_my_claim('role')::text IN ('Admin', 'Warden')) WITH CHECK (get_my_claim('role')::text IN ('Admin', 'Warden'));
CREATE POLICY "Allow individual read access" ON public.students FOR SELECT USING (auth.uid() = profile_id);

-- Rooms: Authenticated users can read all. Only Admins/Wardens can modify.
CREATE POLICY "Allow all authenticated read access" ON public.rooms FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin/warden write access" ON public.rooms FOR ALL USING (get_my_claim('role')::text IN ('Admin', 'Warden')) WITH CHECK (get_my_claim('role')::text IN ('Admin', 'Warden'));

-- Fees: Admins/Wardens can see all. Students can see their own fees.
CREATE POLICY "Allow admin/warden full access" ON public.fees FOR ALL USING (get_my_claim('role')::text IN ('Admin', 'Warden')) WITH CHECK (get_my_claim('role')::text IN ('Admin', 'Warden'));
CREATE POLICY "Allow individual read access" ON public.fees FOR SELECT USING (auth.uid() = (SELECT profile_id FROM students WHERE id = student_id));

-- Payments: Admins/Wardens can see all. Students can see payments for their own fees.
CREATE POLICY "Allow admin/warden full access" ON public.payments FOR ALL USING (get_my_claim('role')::text IN ('Admin', 'Warden')) WITH CHECK (get_my_claim('role')::text IN ('Admin', 'Warden'));
CREATE POLICY "Allow individual read access" ON public.payments FOR SELECT USING (auth.uid() = (SELECT s.profile_id FROM students s JOIN fees f ON s.id = f.student_id WHERE f.id = fee_id));

-- Complaints: Admins/Wardens can see all. Students can manage their own.
CREATE POLICY "Allow admin/warden full access" ON public.complaints FOR ALL USING (get_my_claim('role')::text IN ('Admin', 'Warden')) WITH CHECK (get_my_claim('role')::text IN ('Admin', 'Warden'));
CREATE POLICY "Allow individual access" ON public.complaints FOR ALL USING (auth.uid() = (SELECT profile_id FROM students WHERE id = student_id));

-- Visitors & Notices & Activity Log: Public read for authenticated, write for admin/warden.
CREATE POLICY "Allow authenticated read" ON public.visitors FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin/warden write" ON public.visitors FOR INSERT WITH CHECK (get_my_claim('role')::text IN ('Admin', 'Warden'));
CREATE POLICY "Allow authenticated read" ON public.notices FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin write" ON public.notices FOR INSERT WITH CHECK (get_my_claim('role')::text = 'Admin');
CREATE POLICY "Allow authenticated read" ON public.activity_log FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Allow admin/warden write" ON public.activity_log FOR INSERT WITH CHECK (get_my_claim('role')::text IN ('Admin', 'Warden'));

-- =================================================================
-- Step 5: Database Functions & Triggers
-- =================================================================

-- Function to get user's role from JWT claims
CREATE OR REPLACE FUNCTION get_my_claim(claim TEXT)
RETURNS TEXT
LANGUAGE sql STABLE
AS $$
  SELECT nullif(current_setting('request.jwt.claims', true)::jsonb ->> claim, '')::text;
$$;

-- Function to create a profile and student entry for a new user
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  user_role_from_meta user_role;
BEGIN
  -- Extract role from metadata, default to 'Student'
  user_role_from_meta := (new.raw_user_meta_data->>'role')::user_role;
  IF user_role_from_meta IS NULL THEN
    user_role_from_meta := 'Student';
  END IF;

  -- Create a profile
  INSERT INTO public.profiles (id, full_name, role)
  VALUES (new.id, new.raw_user_meta_data->>'full_name', user_role_from_meta);

  -- If the user is a student, create a corresponding student entry
  IF user_role_from_meta = 'Student' THEN
    INSERT INTO public.students (profile_id, name)
    VALUES (new.id, new.raw_user_meta_data->>'full_name');
  END IF;
  
  RETURN new;
END;
$$;

-- Trigger to call the function on new user signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- =================================================================
-- Step 6: RPC Functions for Business Logic
-- =================================================================

CREATE OR REPLACE FUNCTION public.update_student_details_and_allocate_room(
    p_user_id uuid,
    p_course text,
    p_contact text,
    p_joining_date date,
    p_status text,
    p_room_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
    -- Update the student record
    UPDATE public.students
    SET
        course = p_course,
        contact = p_contact,
        joining_date = p_joining_date,
        status = p_status::student_status,
        room_id = p_room_id
    WHERE profile_id = p_user_id;

    -- If a room was assigned, update its status
    IF p_room_id IS NOT NULL THEN
        UPDATE public.rooms
        SET status = 'Occupied'
        WHERE id = p_room_id;
        
        INSERT INTO public.activity_log (text, icon)
        VALUES ('A student was assigned to room ' || (SELECT room_no FROM rooms WHERE id = p_room_id), 'user-check');
    END IF;
END;
$$;


CREATE OR REPLACE FUNCTION public.add_room(p_room_no text, p_block text, p_type text, p_capacity integer)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.rooms (room_no, block, type, capacity)
  VALUES (p_room_no, p_block, p_type::room_type, p_capacity);
END;
$$;

CREATE OR REPLACE FUNCTION public.log_visitor(p_name text, p_contact text, p_student_id uuid, p_purpose text)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.visitors (name, contact, student_id, purpose)
  VALUES (p_name, p_contact, p_student_id, p_purpose);
END;
$$;

CREATE OR REPLACE FUNCTION public.checkout_visitor(p_visitor_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.visitors SET out_time = now() WHERE id = p_visitor_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.add_complaint(p_student_id uuid, p_title text, p_description text)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_room_id uuid;
BEGIN
    SELECT room_id INTO v_room_id FROM public.students WHERE id = p_student_id;
    INSERT INTO public.complaints (student_id, room_id, title, description)
    VALUES (p_student_id, v_room_id, p_title, p_description);
END;
$$;

CREATE OR REPLACE FUNCTION public.resolve_complaint(p_complaint_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.complaints SET status = 'Resolved' WHERE id = p_complaint_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.record_payment(p_fee_id uuid, p_amount numeric, p_payment_method text)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_paid numeric;
    v_total_amount numeric;
BEGIN
    INSERT INTO public.payments (fee_id, amount, payment_method)
    VALUES (p_fee_id, p_amount, p_payment_method);

    SELECT total_amount INTO v_total_amount FROM public.fees WHERE id = p_fee_id;
    SELECT SUM(amount) INTO v_total_paid FROM public.payments WHERE fee_id = p_fee_id;

    IF v_total_paid >= v_total_amount THEN
        UPDATE public.fees SET status = 'Paid' WHERE id = p_fee_id;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_recent_activity()
RETURNS TABLE(id bigint, created_at timestamptz, text text, icon text)
LANGUAGE sql STABLE
AS $$
  SELECT id, created_at, text, icon FROM public.activity_log ORDER BY created_at DESC LIMIT 5;
$$;
