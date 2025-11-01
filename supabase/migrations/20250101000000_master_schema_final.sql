-- =================================================================
-- 1. Profiles Table & Auth Trigger
-- Stores public user data and links to auth.users
-- =================================================================

-- Create the profiles table
CREATE TABLE public.profiles (
    id uuid NOT NULL PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name text,
    role text NOT NULL DEFAULT 'Student'::text,
    updated_at timestamp with time zone
);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- RLS Policies for profiles
CREATE POLICY "Public profiles are viewable by everyone." ON public.profiles FOR SELECT USING (true);
CREATE POLICY "Users can insert their own profile." ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
CREATE POLICY "Users can update their own profile." ON public.profiles FOR UPDATE USING (auth.uid() = id);

-- Trigger to create a profile when a new user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, full_name, role)
  VALUES (new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'role');
  RETURN new;
END;
$$;

-- Link trigger to auth.users table
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- =================================================================
-- 2. Rooms Table
-- Stores information about each hostel room
-- =================================================================
CREATE TABLE public.rooms (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    room_no text NOT NULL UNIQUE,
    block text NOT NULL,
    type text NOT NULL,
    capacity integer NOT NULL DEFAULT 1,
    status text NOT NULL DEFAULT 'Available'::text,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;

-- RLS Policies for rooms
CREATE POLICY "Authenticated users can view rooms." ON public.rooms FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Admins and Wardens can manage rooms." ON public.rooms FOR ALL USING (
    (SELECT profiles.role FROM profiles WHERE profiles.id = auth.uid()) IN ('Admin', 'Warden')
);


-- =================================================================
-- 3. Students Table
-- Stores detailed student information, linked to a profile
-- =================================================================
CREATE TABLE public.students (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
    name text,
    course text,
    contact text,
    joining_date date,
    room_id uuid REFERENCES public.rooms(id) ON DELETE SET NULL,
    status text NOT NULL DEFAULT 'Active'::text,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;

-- Function to create a student record from a profile
CREATE OR REPLACE FUNCTION public.create_student_from_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.students (user_id, name)
  VALUES (new.id, new.full_name);
  RETURN new;
END;
$$;

-- Trigger to create a student when a profile is created
CREATE TRIGGER on_profile_created
  AFTER INSERT ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.create_student_from_profile();

-- RLS Policies for students
CREATE POLICY "Admins and Wardens can view all students." ON public.students FOR SELECT USING (
    (SELECT profiles.role FROM profiles WHERE profiles.id = auth.uid()) IN ('Admin', 'Warden')
);
CREATE POLICY "Students can view their own record." ON public.students FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Admins and Wardens can manage students." ON public.students FOR ALL USING (
    (SELECT profiles.role FROM profiles WHERE profiles.id = auth.uid()) IN ('Admin', 'Warden')
);


-- =================================================================
-- 4. Fees, Payments, and Visitors Tables
-- =================================================================
CREATE TABLE public.fees (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    total_amount numeric(10, 2) NOT NULL,
    due_date date NOT NULL,
    status text NOT NULL DEFAULT 'Pending'::text,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);
ALTER TABLE public.fees ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.payments (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    fee_id uuid NOT NULL REFERENCES public.fees(id) ON DELETE CASCADE,
    amount numeric(10, 2) NOT NULL,
    payment_method text NOT NULL,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.visitors (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    name text NOT NULL,
    contact text,
    student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    purpose text,
    in_time timestamp with time zone NOT NULL DEFAULT now(),
    out_time timestamp with time zone
);
ALTER TABLE public.visitors ENABLE ROW LEVEL SECURITY;

-- RLS Policies for fees, payments, visitors
CREATE POLICY "Admins/Wardens can manage fees, payments, visitors." ON public.fees FOR ALL USING ((SELECT profiles.role FROM profiles WHERE profiles.id = auth.uid()) IN ('Admin', 'Warden'));
CREATE POLICY "Students can view their own fees." ON public.fees FOR SELECT USING ((EXISTS (SELECT 1 FROM students WHERE students.id = student_id AND students.user_id = auth.uid())));
CREATE POLICY "Admins/Wardens can manage payments." ON public.payments FOR ALL USING ((SELECT profiles.role FROM profiles WHERE profiles.id = auth.uid()) IN ('Admin', 'Warden'));
CREATE POLICY "Admins/Wardens can manage visitors." ON public.visitors FOR ALL USING ((SELECT profiles.role FROM profiles WHERE profiles.id = auth.uid()) IN ('Admin', 'Warden'));


-- =================================================================
-- 5. Complaints and Notices Tables
-- =================================================================
CREATE TABLE public.complaints (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    student_id uuid NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    title text NOT NULL,
    description text,
    status text NOT NULL DEFAULT 'Pending'::text,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);
ALTER TABLE public.complaints ENABLE ROW LEVEL SECURITY;

CREATE TABLE public.notices (
    id uuid NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    title text NOT NULL,
    message text,
    created_at timestamp with time zone NOT NULL DEFAULT now()
);
ALTER TABLE public.notices ENABLE ROW LEVEL SECURITY;

-- RLS Policies for complaints and notices
CREATE POLICY "Authenticated users can view notices." ON public.notices FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Admins can manage notices." ON public.notices FOR ALL USING ((SELECT profiles.role FROM profiles WHERE profiles.id = auth.uid()) = 'Admin');
CREATE POLICY "Admins/Wardens can view all complaints." ON public.complaints FOR SELECT USING ((SELECT profiles.role FROM profiles WHERE profiles.id = auth.uid()) IN ('Admin', 'Warden'));
CREATE POLICY "Students can manage their own complaints." ON public.complaints FOR ALL USING ((EXISTS (SELECT 1 FROM students WHERE students.id = student_id AND students.user_id = auth.uid())));
CREATE POLICY "Admins/Wardens can update complaint status." ON public.complaints FOR UPDATE USING ((SELECT profiles.role FROM profiles WHERE profiles.id = auth.uid()) IN ('Admin', 'Warden'));


-- =================================================================
-- 6. RPC Functions for Business Logic
-- =================================================================

-- Function to update student details and allocate a room
CREATE OR REPLACE FUNCTION public.update_student_details_and_allocate_room(p_user_id uuid, p_course text, p_contact text, p_joining_date date, p_status text, p_room_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  UPDATE public.students
  SET
    course = p_course,
    contact = p_contact,
    joining_date = p_joining_date,
    status = p_status,
    room_id = p_room_id
  WHERE user_id = p_user_id;

  IF p_room_id IS NOT NULL THEN
    UPDATE public.rooms
    SET status = 'Occupied'
    WHERE id = p_room_id;
  END IF;
END;
$$;

-- Function to add a room
CREATE OR REPLACE FUNCTION public.add_room(p_room_no text, p_block text, p_type text, p_capacity int)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.rooms(room_no, block, type, capacity)
  VALUES (p_room_no, p_block, p_type, p_capacity);
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

-- Function to checkout a visitor
CREATE OR REPLACE FUNCTION public.checkout_visitor(p_visitor_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.visitors SET out_time = now() WHERE id = p_visitor_id;
END;
$$;

-- Function to add a complaint
CREATE OR REPLACE FUNCTION public.add_complaint(p_title text, p_description text, p_student_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  INSERT INTO public.complaints(student_id, title, description)
  VALUES (p_student_id, p_title, p_description);
END;
$$;

-- Function to resolve a complaint
CREATE OR REPLACE FUNCTION public.resolve_complaint(p_complaint_id uuid)
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  UPDATE public.complaints SET status = 'Resolved' WHERE id = p_complaint_id;
END;
$$;

-- Function to record a payment and update fee status
CREATE OR REPLACE FUNCTION public.record_payment(p_fee_id uuid, p_amount numeric, p_payment_method text)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
  v_total_paid numeric;
  v_total_amount numeric;
BEGIN
  INSERT INTO public.payments(fee_id, amount, payment_method)
  VALUES (p_fee_id, p_amount, p_payment_method);

  SELECT total_amount INTO v_total_amount FROM public.fees WHERE id = p_fee_id;
  SELECT SUM(amount) INTO v_total_paid FROM public.payments WHERE fee_id = p_fee_id;

  IF v_total_paid >= v_total_amount THEN
    UPDATE public.fees SET status = 'Paid' WHERE id = p_fee_id;
  END IF;
END;
$$;

-- Function to get recent activity
CREATE OR REPLACE FUNCTION public.get_recent_activity()
RETURNS TABLE(id uuid, text text, icon text, created_at timestamptz)
LANGUAGE sql
AS $$
  SELECT id, 'New student ' || name || ' joined.' as text, 'user-plus' as icon, created_at FROM students ORDER BY created_at DESC LIMIT 2
  UNION ALL
  SELECT id, 'Complaint raised for room.' as text, 'shield-alert' as icon, created_at FROM complaints ORDER BY created_at DESC LIMIT 2
  UNION ALL
  SELECT id, 'New notice: ' || title as text, 'megaphone' as icon, created_at FROM notices ORDER BY created_at DESC LIMIT 1
  ORDER BY created_at DESC
  LIMIT 5;
$$;
