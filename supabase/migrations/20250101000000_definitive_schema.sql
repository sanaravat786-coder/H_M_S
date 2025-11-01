/*
          # [DEFINITIVE SCHEMA] Hostel Management System
          [This script creates the entire database schema from scratch, including tables, relationships, functions, triggers, and RLS policies. It is designed to be run on a clean public schema.]

          ## Query Description: [This script will set up all necessary database objects for the HMS application. If you have existing tables from previous failed attempts, you MUST delete them from the Supabase Table Editor before running this script to avoid conflicts. This ensures a clean and correct installation.]
          
          ## Metadata:
          - Schema-Category: ["Structural"]
          - Impact-Level: ["High"]
          - Requires-Backup: [true]
          - Reversible: [false]
          
          ## Structure Details:
          - Tables Created: profiles, rooms, students, fees, payments, visitors, complaints, notices, activity_log
          - Functions Created: handle_new_user, create_student_from_profile, get_my_role, and various RPCs for business logic.
          - Triggers Created: on_auth_user_created, on_profile_created
          - RLS Policies: Full RLS setup for all tables based on user roles.
          */

-- 1. EXTENSIONS (Ensure pgcrypto is available)
CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";

-- 2. TABLES
-- Profiles table to store role and other user-specific data
CREATE TABLE public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    role TEXT NOT NULL DEFAULT 'Student'::text
);
COMMENT ON TABLE public.profiles IS 'Stores public-facing profile data for each user.';

-- Rooms table
CREATE TABLE public.rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_no TEXT NOT NULL UNIQUE,
    block TEXT NOT NULL,
    type TEXT NOT NULL,
    capacity INT NOT NULL,
    status TEXT NOT NULL DEFAULT 'Available'::text,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.rooms IS 'Manages all hostel rooms and their status.';

-- Students table, linked to auth users
CREATE TABLE public.students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    email TEXT UNIQUE,
    course TEXT,
    contact TEXT,
    joining_date DATE,
    status TEXT DEFAULT 'Active'::text,
    room_id UUID REFERENCES public.rooms(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.students IS 'Stores detailed information about each student.';

-- Fees table
CREATE TABLE public.fees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    total_amount NUMERIC(10, 2) NOT NULL,
    due_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'Pending'::text,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.fees IS 'Tracks fee invoices for students.';

-- Payments table
CREATE TABLE public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fee_id UUID NOT NULL REFERENCES public.fees(id) ON DELETE CASCADE,
    amount NUMERIC(10, 2) NOT NULL,
    payment_method TEXT NOT NULL,
    payment_date TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.payments IS 'Logs all payments made against fee invoices.';

-- Visitors table
CREATE TABLE public.visitors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    contact TEXT,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    purpose TEXT,
    in_time TIMESTAMPTZ NOT NULL DEFAULT now(),
    out_time TIMESTAMPTZ
);
COMMENT ON TABLE public.visitors IS 'Keeps a log of all visitors.';

-- Complaints table
CREATE TABLE public.complaints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    room_id UUID REFERENCES public.rooms(id) ON DELETE SET NULL,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'Pending'::text,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.complaints IS 'Tracks student complaints about maintenance or other issues.';

-- Notices table
CREATE TABLE public.notices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.notices IS 'Stores announcements made by admins.';

-- Activity Log table
CREATE TABLE public.activity_log (
    id BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    text TEXT NOT NULL,
    icon TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
COMMENT ON TABLE public.activity_log IS 'Logs major events in the system for the dashboard feed.';


-- 3. HELPER FUNCTIONS
-- Function to get the role of the currently authenticated user
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
    SELECT role FROM public.profiles WHERE id = auth.uid();
$$;

-- 4. TRIGGER FUNCTIONS
-- Function to create a profile when a new user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role)
  VALUES (new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'role');
  RETURN new;
END;
$$;

-- Function to create a student entry when a student profile is created
CREATE OR REPLACE FUNCTION public.create_student_from_profile()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF new.role = 'Student' THEN
    INSERT INTO public.students (user_id, name, email)
    VALUES (new.id, new.full_name, (SELECT email FROM auth.users WHERE id = new.id));
  END IF;
  RETURN new;
END;
$$;


-- 5. TRIGGERS
-- Trigger to call handle_new_user on new user signup
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- Trigger to call create_student_from_profile when a profile is created
CREATE TRIGGER on_profile_created
  AFTER INSERT ON public.profiles
  FOR EACH ROW EXECUTE PROCEDURE public.create_student_from_profile();


-- 6. RPC FUNCTIONS (for business logic)

-- Function to add a room and log activity
CREATE OR REPLACE FUNCTION public.add_room(p_room_no text, p_block text, p_type text, p_capacity int)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.rooms(room_no, block, type, capacity)
  VALUES (p_room_no, p_block, p_type, p_capacity);
  
  INSERT INTO public.activity_log(text, icon)
  VALUES ('Room ' || p_room_no || ' was added.', 'bed-double');
END;
$$;

-- Function to update student details and allocate room
CREATE OR REPLACE FUNCTION public.update_student_details_and_allocate_room(p_user_id uuid, p_course text, p_contact text, p_joining_date date, p_status text, p_room_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  -- Update student record
  UPDATE public.students
  SET
    course = p_course,
    contact = p_contact,
    joining_date = p_joining_date,
    status = p_status,
    room_id = p_room_id
  WHERE user_id = p_user_id;

  -- If a room was assigned, update its status
  IF p_room_id IS NOT NULL THEN
    UPDATE public.rooms
    SET status = 'Occupied'
    WHERE id = p_room_id;
  END IF;

  INSERT INTO public.activity_log(text, icon)
  VALUES ((SELECT name FROM public.students WHERE user_id = p_user_id) || ' was registered.', 'user-plus');
END;
$$;

-- Function to log a visitor
CREATE OR REPLACE FUNCTION public.log_visitor(p_name text, p_contact text, p_student_id uuid, p_purpose text)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.visitors(name, contact, student_id, purpose)
  VALUES (p_name, p_contact, p_student_id, p_purpose);
END;
$$;

-- Function to check out a visitor
CREATE OR REPLACE FUNCTION public.checkout_visitor(p_visitor_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.visitors
  SET out_time = now()
  WHERE id = p_visitor_id;
END;
$$;

-- Function to record a payment and update fee status
CREATE OR REPLACE FUNCTION public.record_payment(p_fee_id uuid, p_amount numeric, p_payment_method text)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_total_paid NUMERIC;
  v_total_amount NUMERIC;
BEGIN
  -- Insert the payment
  INSERT INTO public.payments(fee_id, amount, payment_method)
  VALUES (p_fee_id, p_amount, p_payment_method);

  -- Recalculate total paid for the fee
  SELECT COALESCE(SUM(amount), 0) INTO v_total_paid
  FROM public.payments
  WHERE fee_id = p_fee_id;

  -- Get total amount of the fee
  SELECT total_amount INTO v_total_amount
  FROM public.fees
  WHERE id = p_fee_id;

  -- Update fee status if fully paid
  IF v_total_paid >= v_total_amount THEN
    UPDATE public.fees
    SET status = 'Paid'
    WHERE id = p_fee_id;
  END IF;
END;
$$;

-- Function to add a complaint
CREATE OR REPLACE FUNCTION public.add_complaint(p_title text, p_description text, p_student_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_room_id UUID;
BEGIN
  -- Get the student's room
  SELECT room_id INTO v_room_id FROM public.students WHERE id = p_student_id;

  INSERT INTO public.complaints(student_id, room_id, title, description)
  VALUES (p_student_id, v_room_id, p_title, p_description);

  INSERT INTO public.activity_log(text, icon)
  VALUES ('A new complaint was filed for room ' || (SELECT room_no FROM rooms WHERE id = v_room_id), 'shield-alert');
END;
$$;

-- Function to resolve a complaint
CREATE OR REPLACE FUNCTION public.resolve_complaint(p_complaint_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.complaints
  SET status = 'Resolved'
  WHERE id = p_complaint_id;
END;
$$;

-- Function to get recent activity
CREATE OR REPLACE FUNCTION public.get_recent_activity()
RETURNS TABLE(id bigint, text text, icon text, created_at timestamptz)
LANGUAGE sql
AS $$
  SELECT id, text, icon, created_at
  FROM public.activity_log
  ORDER BY created_at DESC
  LIMIT 5;
$$;


-- 7. ROW LEVEL SECURITY (RLS) POLICIES
-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visitors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.complaints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_log ENABLE ROW LEVEL SECURITY;

-- Profiles Policies
CREATE POLICY "Users can view their own profile" ON public.profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Admins can view all profiles" ON public.profiles FOR SELECT USING (public.get_my_role() = 'Admin');
CREATE POLICY "Users can update their own profile" ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Rooms Policies
CREATE POLICY "Authenticated users can view all rooms" ON public.rooms FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Admins and Wardens can manage rooms" ON public.rooms FOR ALL USING (public.get_my_role() IN ('Admin', 'Warden'));

-- Students Policies
CREATE POLICY "Admins and Wardens can view all students" ON public.students FOR SELECT USING (public.get_my_role() IN ('Admin', 'Warden'));
CREATE POLICY "Students can view their own record" ON public.students FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Admins can manage student records" ON public.students FOR ALL USING (public.get_my_role() = 'Admin');

-- Fees Policies
CREATE POLICY "Admins and Wardens can view all fees" ON public.fees FOR SELECT USING (public.get_my_role() IN ('Admin', 'Warden'));
CREATE POLICY "Students can view their own fees" ON public.fees FOR SELECT USING (student_id = (SELECT id FROM public.students WHERE user_id = auth.uid()));
CREATE POLICY "Admins can manage fees" ON public.fees FOR ALL USING (public.get_my_role() = 'Admin');

-- Payments Policies (Inherits from Fees)
CREATE POLICY "Admins and Wardens can view all payments" ON public.payments FOR SELECT USING (public.get_my_role() IN ('Admin', 'Warden'));
CREATE POLICY "Students can view their own payments" ON public.payments FOR SELECT USING (fee_id IN (SELECT id FROM public.fees WHERE student_id = (SELECT id FROM public.students WHERE user_id = auth.uid())));
CREATE POLICY "Admins can manage payments" ON public.payments FOR ALL USING (public.get_my_role() = 'Admin');

-- Visitors Policies
CREATE POLICY "Admins and Wardens can manage visitors" ON public.visitors FOR ALL USING (public.get_my_role() IN ('Admin', 'Warden'));

-- Complaints Policies
CREATE POLICY "Admins and Wardens can manage all complaints" ON public.complaints FOR ALL USING (public.get_my_role() IN ('Admin', 'Warden'));
CREATE POLICY "Students can view and create their own complaints" ON public.complaints FOR ALL USING (student_id = (SELECT id FROM public.students WHERE user_id = auth.uid()));

-- Notices Policies
CREATE POLICY "Authenticated users can view all notices" ON public.notices FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Admins can manage notices" ON public.notices FOR ALL USING (public.get_my_role() = 'Admin');

-- Activity Log Policies
CREATE POLICY "Admins and Wardens can view activity log" ON public.activity_log FOR SELECT USING (public.get_my_role() IN ('Admin', 'Warden'));
</sql>
