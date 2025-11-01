import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { ArrowLeft } from 'lucide-react';
import { Button } from '../../components/ui/Button';
import Badge from '../../components/ui/Badge';
import { InfoCard, InfoRow } from '../../components/InfoCard';
import { supabase } from '../../lib/supabase';
import Spinner from '../../components/ui/Spinner';

const StudentDetailPage = () => {
    const { studentId } = useParams();
    const navigate = useNavigate();
    const [student, setStudent] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const fetchStudent = async () => {
            setLoading(true);
            const { data, error } = await supabase
                .from('students')
                .select(`
                    *,
                    rooms ( room_no, block, type ),
                    fees ( *, payments ( * ) )
                `)
                .eq('id', studentId)
                .single();

            if (error) {
                console.error("Error fetching student details:", error);
            } else {
                setStudent(data);
            }
            setLoading(false);
        };

        fetchStudent();
    }, [studentId]);

    if (loading) {
        return <div className="flex justify-center items-center h-64"><Spinner size="lg" /></div>;
    }

    if (!student) {
        return <div>Student not found.</div>;
    }

    const latestFee = student.fees.length > 0 ? student.fees[0] : null;
    const totalPaid = latestFee ? latestFee.payments.reduce((acc, p) => acc + p.amount, 0) : 0;
    const balance = latestFee ? latestFee.total_amount - totalPaid : 0;

    return (
        <div>
            <Button variant="ghost" onClick={() => navigate(-1)} className="mb-4">
                <ArrowLeft className="mr-2 h-4 w-4" />
                Back to Students
            </Button>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                <div className="lg:col-span-1">
                    <InfoCard title="Student Profile">
                        <div className="flex flex-col items-center">
                            <img src={`https://i.pravatar.cc/150?u=${student.id}`} alt={student.name} className="h-24 w-24 rounded-full mb-4" />
                            <h2 className="text-xl font-bold">{student.name}</h2>
                            <p className="text-muted-foreground">{student.id}</p>
                            <div className="mt-2">
                                <Badge status={student.status} />
                            </div>
                        </div>
                    </InfoCard>
                </div>

                <div className="lg:col-span-2 space-y-6">
                    <InfoCard title="Contact Information">
                        <InfoRow label="Email" value={student.email || 'N/A'} />
                        <InfoRow label="Phone" value={student.contact} />
                    </InfoCard>
                    
                    <InfoCard title="Academic & Hostel Details">
                        <InfoRow label="Course" value={student.course} />
                        <InfoRow label="Joining Date" value={new Date(student.joining_date).toLocaleDateString()} />
                        <InfoRow label="Room No" value={student.rooms?.room_no || 'Not Assigned'} />
                        <InfoRow label="Block" value={student.rooms?.block || 'N/A'} />
                    </InfoCard>

                    <InfoCard title="Fee Status">
                        {latestFee ? (
                            <>
                                <InfoRow label="Total Fees" value={`£${latestFee.total_amount}`} />
                                <InfoRow label="Paid Amount" value={`£${totalPaid}`} />
                                <InfoRow label="Balance" value={`£${balance}`} />
                                <div className="flex justify-between items-center py-2">
                                    <p className="text-sm font-medium text-muted-foreground">Status</p>
                                    <Badge status={latestFee.status} />
                                </div>
                            </>
                        ) : (
                            <p className="text-muted-foreground">No fee records found.</p>
                        )}
                    </InfoCard>
                </div>
            </div>
        </div>
    );
};

export default StudentDetailPage;
