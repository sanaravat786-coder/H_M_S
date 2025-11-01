import React, { useState, useEffect } from 'react';
import StatCard from '../components/StatCard';
import { Users, BedDouble, CircleDollarSign, ShieldAlert } from 'lucide-react';
import OccupancyChart from '../components/OccupancyChart';
import RecentActivity from '../components/RecentActivity';
import Badge from '../components/ui/Badge';
import { supabase } from '../lib/supabase';
import { useAuth } from '../hooks/useAuth';
import Spinner from '../components/ui/Spinner';

const RecentComplaints = ({ complaints = [] }) => {
    if (!complaints || complaints.length === 0) {
        return <p className="text-sm text-muted-foreground">No pending complaints.</p>;
    }
    return (
        <div className="flow-root">
            <ul role="list" className="-mb-8">
                {complaints.map((complaint, complaintIdx) => (
                <li key={complaint.id}>
                    <div className="relative pb-8">
                    {complaintIdx !== complaints.length - 1 ? (
                        <span className="absolute left-4 top-4 -ml-px h-full w-0.5 bg-gray-200 dark:bg-gray-700" aria-hidden="true" />
                    ) : null}
                    <div className="relative flex space-x-3">
                        <div>
                            <span className="h-8 w-8 rounded-full bg-muted dark:bg-dark-muted flex items-center justify-center ring-8 ring-card dark:ring-dark-card">
                                <ShieldAlert className="h-5 w-5 text-muted-foreground" aria-hidden="true" />
                            </span>
                        </div>
                        <div className="flex min-w-0 flex-1 justify-between space-x-4 pt-1.5">
                            <div>
                                <p className="text-sm text-card-foreground dark:text-dark-card-foreground">
                                Complaint in <span className="font-medium">{complaint.rooms.room_no}</span> by {complaint.students.name}
                                </p>
                            </div>
                            <div className="whitespace-nowrap text-right text-sm text-muted-foreground">
                                <Badge status={complaint.status} />
                            </div>
                        </div>
                    </div>
                    </div>
                </li>
                ))}
            </ul>
        </div>
    )
}

const Dashboard = () => {
    const { profile } = useAuth();
    const [stats, setStats] = useState({ students: 0, rooms: 0, fees: 0, complaints: 0 });
    const [occupancyData, setOccupancyData] = useState([]);
    const [recentComplaints, setRecentComplaints] = useState([]);
    const [recentActivities, setRecentActivities] = useState([]);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const fetchDashboardData = async () => {
            setLoading(true);
            try {
                const [studentsCount, roomsData, feesSum, complaintsData, activityData] = await Promise.all([
                    supabase.from('students').select('*', { count: 'exact', head: true }),
                    supabase.from('rooms').select('status, block'),
                    supabase.from('payments').select('amount'),
                    supabase.from('complaints').select('*, students(name), rooms(room_no)').eq('status', 'Pending').limit(5),
                    supabase.rpc('get_recent_activity')
                ]);

                // Stats
                const totalFees = feesSum.data ? feesSum.data.reduce((acc, p) => acc + p.amount, 0) : 0;
                setStats({
                    students: studentsCount.count ?? 0,
                    rooms: roomsData.data?.filter(r => r.status === 'Available').length ?? 0,
                    fees: totalFees,
                    complaints: complaintsData.data?.length ?? 0,
                });

                // Occupancy Chart
                const safeRoomsData = roomsData.data || [];
                const blocks = [...new Set(safeRoomsData.map(r => r.block))];
                const chartData = blocks.map(block => ({
                    name: `Block ${block}`,
                    occupied: safeRoomsData.filter(r => r.block === block && r.status === 'Occupied').length,
                    available: safeRoomsData.filter(r => r.block === block && r.status === 'Available').length,
                }));
                setOccupancyData(chartData);
                
                // Recent Complaints
                setRecentComplaints(complaintsData.data || []);

                // Recent Activity
                setRecentActivities(activityData.data || []);

            } catch (error) {
                console.error("Error fetching dashboard data:", error);
            } finally {
                setLoading(false);
            }
        };

        fetchDashboardData();
    }, []);

    const statCards = [
      { title: 'Total Students', value: stats.students, icon: Users },
      { title: 'Rooms Available', value: stats.rooms, icon: BedDouble },
      { title: 'Fees Collected', value: `£${stats.fees.toLocaleString()}`, icon: CircleDollarSign },
      { title: 'Pending Complaints', value: stats.complaints, icon: ShieldAlert },
    ];

  return (
    <div>
      <h1 className="text-3xl font-bold text-card-foreground dark:text-dark-card-foreground">Dashboard</h1>
      <p className="text-muted-foreground dark:text-dark-muted-foreground mb-6">Welcome back, {profile?.full_name || 'User'}!</p>

      {loading ? (
          <div className="flex justify-center items-center h-64"><Spinner size="lg" /></div>
      ) : (
        <>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
            {statCards.map((stat) => (
              <StatCard key={stat.title} {...stat} />
            ))}
          </div>

          <div className="grid grid-cols-1 lg:grid-cols-3 gap-6 mt-6">
            <div className="lg:col-span-2 bg-card dark:bg-dark-card p-6 rounded-lg shadow-sm">
              <h2 className="text-xl font-semibold mb-4 text-card-foreground dark:text-dark-card-foreground">Room Occupancy</h2>
              <div className="h-80">
                <OccupancyChart data={occupancyData} />
              </div>
            </div>
            <div className="bg-card dark:bg-dark-card p-6 rounded-lg shadow-sm">
              <h2 className="text-xl font-semibold mb-4 text-card-foreground dark:text-dark-card-foreground">Recent Activity</h2>
              <RecentActivity activities={recentActivities} />
            </div>
          </div>
          
          <div className="mt-6 bg-card dark:bg-dark-card p-6 rounded-lg shadow-sm">
            <h2 className="text-xl font-semibold mb-4 text-card-foreground dark:text-dark-card-foreground">Recent Complaints</h2>
            <RecentComplaints complaints={recentComplaints} />
          </div>
        </>
      )}
    </div>
  );
};

export default Dashboard;
