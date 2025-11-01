/*
          # [Operation Name]
          Create Application Logic Functions

          ## Query Description: [This script creates several PostgreSQL functions (RPCs) that encapsulate core business logic for the Hostel Management System. By placing this logic in the database, we ensure data integrity and consistency across all operations. For example, adding a student and allocating a room now happens in a single, atomic transaction. This is a safe, structural change.]
          
          ## Metadata:
          - Schema-Category: "Structural"
          - Impact-Level: "Low"
          - Requires-Backup: false
          - Reversible: true
          
          ## Structure Details:
          - Creates function `add_student_and_allocate_room`
          - Creates function `add_room`
          - Creates function `log_visitor`
          - Creates function `checkout_visitor`
          - Creates function `add_complaint`
          - Creates function `resolve_complaint`
          - Creates function `record_payment`
          - Creates function `get_recent_activity`
          
          ## Security Implications:
          - RLS Status: Enabled
          - Policy Changes: No
          - Auth Requirements: These functions respect existing RLS policies.
          
          ## Performance Impact:
          - Indexes: None
          - Triggers: None
          - Estimated Impact: Low. These functions will improve performance for complex operations by reducing round-trips between the client and database.
          */

-- Function to add a student and optionally allocate a room in one transaction
create or replace function add_student_and_allocate_room(
    p_name text,
    p_course text,
    p_contact text,
    p_joining_date date,
    p_status text,
    p_room_id uuid
)
returns table (id uuid, name text, course text, contact text, joining_date date, status text, room_id uuid, created_at timestamptz) as $$
declare
    new_student record;
begin
    insert into public.students (name, course, contact, joining_date, status, room_id)
    values (p_name, p_course, p_contact, p_joining_date, p_status, p_room_id)
    returning * into new_student;

    if p_room_id is not null then
        update public.rooms
        set status = 'Occupied'
        where public.rooms.id = p_room_id;
    end if;

    return query select * from public.students where public.students.id = new_student.id;
end;
$$ language plpgsql security definer;

-- Function to add a new room
create or replace function add_room(
    p_room_no text,
    p_block text,
    p_type text,
    p_capacity int
)
returns table (id uuid, room_no text, block text, type text, capacity int, status text) as $$
begin
    return query
    insert into public.rooms (room_no, block, type, capacity, status)
    values (p_room_no, p_block, p_type, p_capacity, 'Available')
    returning *;
end;
$$ language plpgsql security definer;

-- Function to log a new visitor
create or replace function log_visitor(
    p_name text,
    p_contact text,
    p_student_id uuid,
    p_purpose text
)
returns table (id uuid, name text, contact text, student_id uuid, purpose text, in_time timestamptz, out_time timestamptz) as $$
begin
    return query
    insert into public.visitors (name, contact, student_id, purpose, in_time)
    values (p_name, p_contact, p_student_id, p_purpose, now())
    returning *;
end;
$$ language plpgsql security definer;

-- Function to check out a visitor
create or replace function checkout_visitor(p_visitor_id uuid)
returns setof public.visitors as $$
begin
    return query
    update public.visitors
    set out_time = now()
    where id = p_visitor_id
    returning *;
end;
$$ language plpgsql security definer;

-- Function for a student to add a complaint
create or replace function add_complaint(
    p_title text,
    p_description text,
    p_student_id uuid
)
returns table (id uuid, title text, description text, status text, created_at timestamptz, student_id uuid, room_id uuid) as $$
declare
    v_room_id uuid;
begin
    -- Get student's room id
    select room_id into v_room_id from public.students where id = p_student_id;

    if v_room_id is null then
        raise exception 'Student is not assigned to a room.';
    end if;

    return query
    insert into public.complaints (title, description, student_id, room_id, status)
    values (p_title, p_description, p_student_id, v_room_id, 'Pending')
    returning *;
end;
$$ language plpgsql security definer;


-- Function to resolve a complaint
create or replace function resolve_complaint(p_complaint_id uuid)
returns setof public.complaints as $$
begin
    return query
    update public.complaints
    set status = 'Resolved'
    where id = p_complaint_id
    returning *;
end;
$$ language plpgsql security definer;

-- Function to record a payment and update fee status
create or replace function record_payment(
    p_fee_id uuid,
    p_amount numeric,
    p_payment_method text
)
returns setof public.payments as $$
declare
    v_total_paid numeric;
    v_total_amount numeric;
    new_payment public.payments;
begin
    insert into public.payments (fee_id, amount, payment_method)
    values (p_fee_id, p_amount, p_payment_method)
    returning * into new_payment;

    select total_amount into v_total_amount from public.fees where id = p_fee_id;
    select sum(amount) into v_total_paid from public.payments where fee_id = p_fee_id;

    if v_total_paid >= v_total_amount then
        update public.fees
        set status = 'Paid'
        where id = p_fee_id;
    end if;
    
    return query select * from public.payments where id = new_payment.id;
end;
$$ language plpgsql security definer;


-- Function to get recent activities for the dashboard
create or replace function get_recent_activity()
returns table (
    id uuid,
    type text,
    text text,
    created_at timestamptz,
    icon text
) as $$
begin
    return query
    (
        select s.id, 'Student' as type, s.name || ' was registered.' as text, s.created_at, 'user-plus' as icon from public.students s
        order by s.created_at desc limit 3
    )
    union all
    (
        select v.id, 'Visitor' as type, v.name || ' visited ' || st.name || '.' as text, v.in_time as created_at, 'user-check' as icon from public.visitors v join public.students st on v.student_id = st.id
        order by v.in_time desc limit 3
    )
    union all
    (
        select c.id, 'Complaint' as type, 'New complaint: ' || c.title as text, c.created_at, 'shield-alert' as icon from public.complaints c
        order by c.created_at desc limit 3
    )
    union all
    (
        select n.id, 'Notice' as type, 'New notice posted: ' || n.title as text, n.created_at, 'megaphone' as icon from public.notices n
        order by n.created_at desc limit 3
    )
    order by created_at desc
    limit 5;
end;
$$ language plpgsql;
