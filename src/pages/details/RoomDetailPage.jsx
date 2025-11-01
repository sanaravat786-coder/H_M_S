import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { ArrowLeft } from 'lucide-react';
import { Button } from '../../components/ui/Button';
import Badge from '../../components/ui/Badge';
import { InfoCard, InfoRow } from '../../components/InfoCard';
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '../../components/ui/Table';
import { supabase } from '../../lib/supabase';
import Spinner from '../../components/ui/Spinner';

const RoomDetailPage = () => {
    const { roomId } = useParams();
    const navigate = useNavigate();
    const [room, setRoom] = useState(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const fetchRoom = async () => {
            setLoading(true);
            const { data, error } = await supabase
                .from('rooms')
                .select('*, students(*)')
                .eq('id', roomId)
                .single();
            
            if (error) {
                console.error("Error fetching room details:", error);
            } else {
                setRoom(data);
            }
            setLoading(false);
        };
        fetchRoom();
    }, [roomId]);

    if (loading) {
        return <div className="flex justify-center items-center h-64"><Spinner size="lg" /></div>;
    }

    if (!room) {
        return <div>Room not found.</div>;
    }

    return (
        <div>
            <Button variant="ghost" onClick={() => navigate(-1)} className="mb-4">
                <ArrowLeft className="mr-2 h-4 w-4" />
                Back to Rooms
            </Button>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                <div className="lg:col-span-1">
                    <InfoCard title="Room Details">
                        <div className="space-y-4">
                            <InfoRow label="Room Number" value={room.room_no} />
                            <InfoRow label="Block" value={room.block} />
                            <InfoRow label="Type" value={room.type} />
                            <InfoRow label="Capacity" value={room.capacity} />
                            <div className="flex justify-between items-center py-2">
                                <p className="text-sm font-medium text-muted-foreground">Status</p>
                                <Badge status={room.status} />
                            </div>
                        </div>
                    </InfoCard>
                </div>

                <div className="lg:col-span-2">
                    <InfoCard title="Occupants">
                        {room.students && room.students.length > 0 ? (
                            <Table>
                                <TableHeader>
                                    <TableRow>
                                        <TableHead>Student</TableHead>
                                        <TableHead>Student ID</TableHead>
                                    </TableRow>
                                </TableHeader>
                                <TableBody>
                                    {room.students.map(occ => (
                                        <TableRow key={occ.id}>
                                            <TableCell>
                                                <div className="flex items-center gap-3">
                                                    <img src={`https://i.pravatar.cc/150?u=${occ.id}`} alt={occ.name} className="h-10 w-10 rounded-full object-cover" />
                                                    <div className="font-medium">{occ.name}</div>
                                                </div>
                                            </TableCell>
                                            <TableCell>{occ.id}</TableCell>
                                        </TableRow>
                                    ))}
                                </TableBody>
                            </Table>
                        ) : (
                            <p className="text-muted-foreground">This room is currently available.</p>
                        )}
                    </InfoCard>
                </div>
            </div>
        </div>
    );
};

export default RoomDetailPage;
