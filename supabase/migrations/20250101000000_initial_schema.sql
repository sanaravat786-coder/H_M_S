/*
# [Initial Schema Setup]
This script establishes the complete database schema for the Hostel Management System.

## Query Description:
This is a foundational script that creates all necessary tables, defines relationships with foreign keys, enables Row Level Security (RLS) on all tables, and sets up policies to ensure users can only access their own data or data relevant to their role (Admin/Warden). It also includes a trigger to automatically create a user profile upon successful signup. This is a safe, structural operation as it only creates new objects and does not modify or delete existing data.

## Metadata:
- Schema-Category: "Structural"
- Impact-Level: "Low"
- Requires-Backup: false
- Reversible: true (by dropping the tables)

## Structure Details:
- Tables Created: users, students, rooms, allocations, fees, payments, visitors, complaints, notices.
- Triggers Created: on_auth_user_created.
- RLS Policies: Enabled and configured for all tables.

## Security Implications:
- RLS Status: Enabled on all new tables.
- Policy Changes: Yes, new policies are created to enforce data access rules.
- Auth Requirements: Policies are based on the authenticated user's ID and a custom 'role' in the 'users' table.

## Performance Impact:
- Indexes: Primary keys and foreign keys are indexed by default.
- Triggers: One trigger is added to the auth.users table.
- Estimated Impact: Minimal performance impact on a new database.
*/

-- 1. USER PROFILES TABLE
-- Stores public-facing user information and role.
CREATE TABLE public.users (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT,
    avatar_url TEXT,
    role TEXT NOT NULL DEFAULT 'Student'
);
COMMENT ON TABLE public.users IS 'Profile information for users, linked to authentication.';

-- Enable RLS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Policies for users table
CREATE POLICY "Users can view their own profile."
    ON public.users FOR SELECT
    USING ( auth.uid() = id );

CREATE POLICY "Users can update their own profile."
    ON public.users FOR UPDATE
    USING ( auth.uid() = id );

-- 2. ROOMS TABLE
CREATE TABLE public.rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_no TEXT NOT NULL UNIQUE,
    block TEXT,
    type TEXT NOT NULL, -- e.g., 'Single', 'Double'
    capacity INT NOT NULL,
    status TEXT NOT NULL DEFAULT 'Available' -- e.g., 'Available', 'Occupied', 'Maintenance'
);
COMMENT ON TABLE public.rooms IS 'Information about each hostel room.';

-- Enable RLS
ALTER TABLE public.rooms ENABLE ROW LEVEL SECURITY;

-- Policies for rooms table
CREATE POLICY "Authenticated users can view all rooms."
    ON public.rooms FOR SELECT
    USING ( auth.role() = 'authenticated' );

CREATE POLICY "Admins and Wardens can manage rooms."
    ON public.rooms FOR ALL
    USING ( (SELECT role FROM public.users WHERE id = auth.uid()) IN ('Admin', 'Warden') )
    WITH CHECK ( (SELECT role FROM public.users WHERE id = auth.uid()) IN ('Admin', 'Warden') );


-- 3. STUDENTS TABLE
CREATE TABLE public.students (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID UNIQUE REFERENCES public.users(id) ON DELETE SET NULL,
    name TEXT NOT NULL,
    course TEXT,
    joining_date DATE NOT NULL DEFAULT CURRENT_DATE,
    contact_phone TEXT,
    status TEXT NOT NULL DEFAULT 'Active' -- e.g., 'Active', 'Inactive'
);
COMMENT ON TABLE public.students IS 'Records of all students in the hostel.';

-- Enable RLS
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;

-- Policies for students table
CREATE POLICY "Students can view their own record."
    ON public.students FOR SELECT
    USING ( user_id = auth.uid() );

CREATE POLICY "Admins and Wardens can view all students."
    ON public.students FOR SELECT
    USING ( (SELECT role FROM public.users WHERE id = auth.uid()) IN ('Admin', 'Warden') );

CREATE POLICY "Admins and Wardens can manage student records."
    ON public.students FOR ALL
    USING ( (SELECT role FROM public.users WHERE id = auth.uid()) IN ('Admin', 'Warden') )
    WITH CHECK ( (SELECT role FROM public.users WHERE id = auth.uid()) IN ('Admin', 'Warden') );


-- 4. ALLOCATIONS TABLE
CREATE TABLE public.allocations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    room_id UUID NOT NULL REFERENCES public.rooms(id) ON DELETE CASCADE,
    date_allocated DATE NOT NULL DEFAULT CURRENT_DATE,
    date_vacated DATE,
    is_active BOOLEAN DEFAULT true,
    UNIQUE(student_id, is_active)
);
COMMENT ON TABLE public.allocations IS 'Tracks which student is allocated to which room.';

-- Enable RLS
ALTER TABLE public.allocations ENABLE ROW LEVEL SECURITY;

-- Policies for allocations table
CREATE POLICY "Students can view their own allocation."
    ON public.allocations FOR SELECT
    USING ( (SELECT user_id FROM public.students WHERE id = student_id) = auth.uid() );

CREATE POLICY "Admins and Wardens can view all allocations."
    ON public.allocations FOR SELECT
    USING ( (SELECT role FROM public.users WHERE id = auth.uid()) IN ('Admin', 'Warden') );

CREATE POLICY "Admins and Wardens can manage allocations."
    ON public.allocations FOR ALL
    USING ( (SELECT role FROM public.users WHERE id = auth.uid()) IN ('Admin', 'Warden') )
    WITH CHECK ( (SELECT role FROM public.users WHERE id = auth.uid()) IN ('Admin', 'Warden') );


-- 5. FEES TABLE
CREATE TABLE public.fees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    amount NUMERIC(10, 2) NOT NULL,
    due_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'Pending' -- e.g., 'Pending', 'Paid', 'Overdue'
);
COMMENT ON TABLE public.fees IS 'Fee records and invoices for students.';

-- Enable RLS
ALTER TABLE public.fees ENABLE ROW LEVEL SECURITY;

-- Policies for fees table
CREATE POLICY "Students can view their own fee records."
    ON public.fees FOR SELECT
    USING ( (SELECT user_id FROM public.students WHERE id = student_id) = auth.uid() );

CREATE POLICY "Admins and Wardens can view all fee records."
    ON public.fees FOR SELECT
    USING ( (SELECT role FROM public.users WHERE id = auth.uid()) IN ('Admin', 'Warden') );

CREATE POLICY "Admins can manage fee records."
    ON public.fees FOR ALL
    USING ( (SELECT role FROM public.users WHERE id = auth.uid()) = 'Admin' )
    WITH CHECK ( (SELECT role FROM public.users WHERE id = auth.uid()) = 'Admin' );


-- 6. PAYMENTS TABLE
CREATE TABLE public.payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    fee_id UUID NOT NULL REFERENCES public.fees(id) ON DELETE CASCADE,
    amount_paid NUMERIC(10, 2) NOT NULL,
    payment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    payment_mode TEXT -- e.g., 'Card', 'Bank Transfer'
);
COMMENT ON TABLE public.payments IS 'Transaction log for fee payments.';

-- Enable RLS
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;

-- Policies for payments table
CREATE POLICY "Students can view their own payments."
    ON public.payments FOR SELECT
    USING ( (SELECT user_id FROM public.students WHERE id = (SELECT student_id FROM public.fees WHERE id = fee_id)) = auth.uid() );

CREATE POLICY "Admins and Wardens can view all payments."
    ON public.payments FOR SELECT
    USING ( (SELECT role FROM public.users WHERE id = auth.uid()) IN ('Admin', 'Warden') );

CREATE POLICY "Admins can manage payments."
    ON public.payments FOR ALL
    USING ( (SELECT role FROM public.users WHERE id = auth.uid()) = 'Admin' )
    WITH CHECK ( (SELECT role FROM public.users WHERE id = auth.uid()) = 'Admin' );


-- 7. VISITORS TABLE
CREATE TABLE public.visitors (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    visitor_name TEXT NOT NULL,
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    check_in_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    check_out_time TIMESTAMPTZ
);
COMMENT ON TABLE public.visitors IS 'Log of visitors to the hostel.';

-- Enable RLS
ALTER TABLE public.visitors ENABLE ROW LEVEL SECURITY;

-- Policies for visitors table
CREATE POLICY "Students can view their own visitors."
    ON public.visitors FOR SELECT
    USING ( (SELECT user_id FROM public.students WHERE id = student_id) = auth.uid() );

CREATE POLICY "Admins and Wardens can manage visitor logs."
    ON public.visitors FOR ALL
    USING ( (SELECT role FROM public.users WHERE id = auth.uid()) IN ('Admin', 'Warden') )
    WITH CHECK ( (SELECT role FROM public.users WHERE id = auth.uid()) IN ('Admin', 'Warden') );


-- 8. COMPLAINTS TABLE
CREATE TABLE public.complaints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'Pending', -- e.g., 'Pending', 'In Progress', 'Resolved'
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public.complaints IS 'Maintenance and other complaints from students.';

-- Enable RLS
ALTER TABLE public.complaints ENABLE ROW LEVEL SECURITY;

-- Policies for complaints table
CREATE POLICY "Students can manage their own complaints."
    ON public.complaints FOR ALL
    USING ( (SELECT user_id FROM public.students WHERE id = student_id) = auth.uid() );

CREATE POLICY "Admins and Wardens can view all complaints."
    ON public.complaints FOR SELECT
    USING ( (SELECT role FROM public.users WHERE id = auth.uid()) IN ('Admin', 'Warden') );

CREATE POLICY "Admins and Wardens can update complaints."
    ON public.complaints FOR UPDATE
    USING ( (SELECT role FROM public.users WHERE id = auth.uid()) IN ('Admin', 'Warden') );


-- 9. NOTICES TABLE
CREATE TABLE public.notices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title TEXT NOT NULL,
    content TEXT,
    posted_by UUID REFERENCES public.users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
COMMENT ON TABLE public.notices IS 'Announcements for all residents.';

-- Enable RLS
ALTER TABLE public.notices ENABLE ROW LEVEL SECURITY;

-- Policies for notices table
CREATE POLICY "All authenticated users can view notices."
    ON public.notices FOR SELECT
    USING ( auth.role() = 'authenticated' );

CREATE POLICY "Admins and Wardens can manage notices."
    ON public.notices FOR ALL
    USING ( (SELECT role FROM public.users WHERE id = auth.uid()) IN ('Admin', 'Warden') )
    WITH CHECK ( (SELECT role FROM public.users WHERE id = auth.uid()) IN ('Admin', 'Warden') );


-- 10. TRIGGER to create a user profile on new user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, full_name, avatar_url, role)
  VALUES (new.id, new.raw_user_meta_data->>'full_name', new.raw_user_meta_data->>'avatar_url', COALESCE(new.raw_user_meta_data->>'role', 'Student'));
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

</sql>
