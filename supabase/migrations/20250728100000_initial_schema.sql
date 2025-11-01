--
-- Create custom types
--
CREATE TYPE public.user_role AS ENUM ('admin', 'warden', 'student');
CREATE TYPE public.room_status AS ENUM ('Available', 'Occupied', 'Maintenance');
CREATE TYPE public.room_type AS ENUM ('Single', 'Double', 'Triple');
CREATE TYPE public.student_status AS ENUM ('Active', 'Inactive');
CREATE TYPE public.fee_status AS ENUM ('Paid', 'Pending', 'Overdue');
CREATE TYPE public.complaint_status AS ENUM ('Pending', 'In Progress', 'Resolved');

--
-- Create users table (references auth.users)
--
CREATE TABLE public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    avatar_url TEXT,
    role user_role NOT NULL DEFAULT 'student'
);

--
-- Function to create a public user profile when a new auth user signs up
--
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.users (id, full_name, avatar_url, role)
    VALUES (
        new.id,
        new.raw_user_meta_data->>'full_name',
        new.raw_user_meta_data->>'avatar_url',
        'student' -- Default role for new sign-ups
    );
    RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

--
-- Trigger to call the function on new user creation
--
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

--
-- Create rooms table
--
CREATE TABLE public.rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_no TEXT NOT NULL UNIQUE,
    block TEXT NOT NULL,
    type room_type NOT NULL,
    capacity INT NOT NULL,
    status room_status NOT NULL DEFAULT 'Available',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

--
-- Create students table
--
CREATE TABLE public.students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE REFERENCES public.users(id) ON DELETE SET NULL,
    student_reg_id TEXT UNIQUE NOT NULL,
    course TEXT,
    year INT,
    contact_no TEXT,
    status student_status NOT NULL DEFAULT 'Active',
    room_id UUID REFERENCES public.rooms(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

--
-- Create allocations table
--
CREATE TABLE public.allocations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    date_allocated TIMESTAMPTZ DEFAULT NOW(),
    date_vacated TIMESTAMPTZ,
    is_active BOOLEAN DEFAULT TRUE
);

--
-- Create fees table
--
CREATE TABLE public.fees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    total_amount NUMERIC(10, 2) NOT NULL,
    paid_amount NUMERIC(10, 2) DEFAULT 0.00,
    balance NUMERIC(10, 2) GENERATED ALWAYS AS (total_amount - paid_amount) STORED,
    due_date DATE NOT NULL,
    status fee_status NOT NULL DEFAULT 'Pending',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

--
-- Create payments table
--
CREATE TABLE public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fee_id UUID NOT NULL REFERENCES public.fees(id) ON DELETE CASCADE,
    amount NUMERIC(10, 2) NOT NULL,
    payment_mode TEXT,
    payment_date TIMESTAMPTZ DEFAULT NOW()
);

--
-- Create visitors table
--
CREATE TABLE public.visitors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    visitor_name TEXT NOT NULL,
    visitor_contact TEXT,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    purpose TEXT,
    in_time TIMESTAMPTZ DEFAULT NOW(),
    out_time TIMESTAMPTZ
);

--
-- Create complaints table
--
CREATE TABLE public.complaints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    status complaint_status NOT NULL DEFAULT 'Pending',
    created_at TIMESTAMPTZ DEFAULT NOW()
);

--
-- Create notices table
--
CREATE TABLE public.notices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    message TEXT NOT NULL,
    posted_by UUID REFERENCES public.users(id),
    created_at TIMESTAMPTZ DEFAULT NOW()
);


--
-- RLS Policies
--

-- Enable RLS for all tables
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fees ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.visitors ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.complaints ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notices ENABLE ROW LEVEL SECURITY;

--
-- Policies for 'users' table
--
CREATE POLICY "Users can view their own profile" ON public.users
    FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Admins and Wardens can view all user profiles" ON public.users
    FOR SELECT USING (
        (SELECT role FROM public.users WHERE id = auth.uid()) IN ('admin', 'warden')
    );
CREATE POLICY "Users can update their own profile" ON public.users
    FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

--
-- Policies for 'rooms' table
--
CREATE POLICY "Authenticated users can view all rooms" ON public.rooms
    FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Admins and Wardens can manage rooms" ON public.rooms
    FOR ALL USING (
        (SELECT role FROM public.users WHERE id = auth.uid()) IN ('admin', 'warden')
    );

--
-- Policies for 'students' table
--
CREATE POLICY "Students can view their own record" ON public.students
    FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Admins and Wardens can view all student records" ON public.students
    FOR SELECT USING (
        (SELECT role FROM public.users WHERE id = auth.uid()) IN ('admin', 'warden')
    );
CREATE POLICY "Admins and Wardens can manage student records" ON public.students
    FOR ALL USING (
        (SELECT role FROM public.users WHERE id = auth.uid()) IN ('admin', 'warden')
    );

--
-- Policies for 'fees' table
--
CREATE POLICY "Students can view their own fees" ON public.fees
    FOR SELECT USING (
        student_id IN (SELECT id FROM public.students WHERE user_id = auth.uid())
    );
CREATE POLICY "Admins and Wardens can view all fees" ON public.fees
    FOR SELECT USING (
        (SELECT role FROM public.users WHERE id = auth.uid()) IN ('admin', 'warden')
    );
CREATE POLICY "Admins can manage fees" ON public.fees
    FOR ALL USING (
        (SELECT role FROM public.users WHERE id = auth.uid()) = 'admin'
    );

--
-- Policies for 'complaints' table
--
CREATE POLICY "Students can manage their own complaints" ON public.complaints
    FOR ALL USING (
        student_id IN (SELECT id FROM public.students WHERE user_id = auth.uid())
    );
CREATE POLICY "Admins and Wardens can manage all complaints" ON public.complaints
    FOR ALL USING (
        (SELECT role FROM public.users WHERE id = auth.uid()) IN ('admin', 'warden')
    );

--
-- Policies for 'notices' and 'visitors' (public read for authenticated)
--
CREATE POLICY "Authenticated users can view notices and visitors" ON public.notices
    FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Authenticated users can view visitors" ON public.visitors
    FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Admins and Wardens can manage notices and visitors" ON public.notices
    FOR ALL USING (
        (SELECT role FROM public.users WHERE id = auth.uid()) IN ('admin', 'warden')
    );
CREATE POLICY "Admins and Wardens can manage visitors" ON public.visitors
    FOR ALL USING (
        (SELECT role FROM public.users WHERE id = auth.uid()) IN ('admin', 'warden')
    );
