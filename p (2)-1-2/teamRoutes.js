router.post('/leave', async (req, res) => {
  const { teamId, userId } = req.body;

  if (!teamId || !userId) {
    return res.status(400).json({ message: 'Team ID and User ID are required' });
  }

  const connection = await pool.getConnection();
  try {
    await connection.beginTransaction();

    // Check if user is in the team
    const [teamMembers] = await connection.query(
      'SELECT * FROM team_members WHERE team_id = ? AND user_id = ?',
      [teamId, userId]
    );

    if (teamMembers.length === 0) {
      return res.status(400).json({ message: 'User is not a member of this team' });
    }

    // Remove user from team
    await connection.query(
      'DELETE FROM team_members WHERE team_id = ? AND user_id = ?',
      [teamId, userId]
    );

    // Get user's name for notification
    const [users] = await connection.query(
      'SELECT name FROM users WHERE id = ?',
      [userId]
    );
    const userName = users[0]?.name || 'Unknown User';

    await connection.commit();

    // Notify other team members via socket
    io.to(teamId).emit('userLeft', {
      teamId,
      userId,
      userName,
    });

    res.json({ message: '✅ User left the team successfully' });
  } catch (error) {
    await connection.rollback();
    console.error('Error leaving team:', error);
    res.status(500).json({ message: 'Error leaving team' });
  } finally {
    connection.release();
  }
}); 