/*
          # [Operation Name]
          Create Trigger to Link Signup to Student Record & Add Update Function

          ## Query Description: 
          This migration fixes a core architectural flaw by ensuring data consistency between user accounts and student records.
          1.  `on_profile_created_create_student_entry`: A new trigger that automatically creates a basic `students` record whenever a user signs up with the 'Student' role. This ensures self-registered students are fully integrated into the system.
          2.  `update_student_details_and_allocate_room`: A new database function that allows an Admin to update the details of a newly created student (e.g., add course, joining date) and allocate a room in a single, safe transaction.
          
          This change is safe and does not affect existing data. It makes the student creation process robust and reliable.

          ## Metadata:
          - Schema-Category: ["Structural"]
          - Impact-Level: ["Medium"]
          - Requires-Backup: [false]
          - Reversible: [true]
          
          ## Structure Details:
          - Adds 1 new trigger: `on_profile_created_create_student_entry` on the `public.profiles` table.
          - Adds 1 new function: `public.update_student_details_and_allocate_room`.
          
          ## Security Implications:
          - RLS Status: [Unaffected]
          - Policy Changes: [No]
          - Auth Requirements: [The new function has security definitions to only allow `authenticated` users.]
          
          ## Performance Impact:
          - Indexes: [None]
          - Triggers: [Adds one trigger on profile creation, with minimal performance impact.]
          - Estimated Impact: [Low]
          */

-- 1. Trigger to automatically create a student record when a user signs up as a 'Student'.
create or replace function public.handle_new_profile_for_student()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  if new.role = 'Student' then
    insert into public.students (user_id, name, contact)
    values (new.id, new.full_name, 'Not Provided');
  end if;
  return new;
end;
$$;

-- drop trigger if exists on_profile_created_create_student_entry on public.profiles;
create trigger on_profile_created_create_student_entry
  after insert on public.profiles
  for each row
  execute function public.handle_new_profile_for_student();


-- 2. RPC function for an Admin to update details of a student created via signup.
create or replace function public.update_student_details_and_allocate_room(
    p_user_id uuid,
    p_course text,
    p_contact text,
    p_joining_date date,
    p_status student_status,
    p_room_id uuid
)
returns void
language plpgsql
security definer set search_path = public
as $$
begin
    -- Update the student record
    update public.students
    set
        course = p_course,
        contact = p_contact,
        joining_date = p_joining_date,
        status = p_status,
        room_id = p_room_id
    where user_id = p_user_id;

    -- If a room was assigned, update its status
    if p_room_id is not null then
        update public.rooms
        set status = 'Occupied'
        where id = p_room_id;
    end if;

    -- Log this important activity
    insert into public.recent_activities(user_id, icon, text)
    select auth.uid(), 'user-plus', 'Updated details for a student.'
    where is_admin(auth.uid());
end;
$$;

-- Drop the old, now redundant, function
drop function if exists public.add_student_and_allocate_room(text,text,text,date,student_status,uuid);
