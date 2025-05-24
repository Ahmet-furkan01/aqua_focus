const express = require('express');
const db = require('../db');
const { v4: uuidv4 } = require('uuid');

module.exports = (io) => {
    const router = express.Router();

// ✅ CREATE TEAM AND ADD REEF
router.post('/create', async (req, res) => {
    try {
        const { room_name, user_id } = req.body;
        if (!room_name || !user_id) {
            return res.status(400).json({ error: 'Room name and user ID required' });
        }

        const room_id = uuidv4();
        const reef_id = uuidv4();

        // Start transaction
        await db.query('START TRANSACTION');

        // Create team
        await db.query('INSERT INTO teams (room_id, room_name) VALUES (?, ?)', [room_id, room_name]);
        
        // Add user to team
        await db.query('INSERT INTO team_members (room_id, user_id) VALUES (?, ?)', [room_id, user_id]);
        
        // Create reef
        await db.query('INSERT INTO team_reefs (reef_id, room_id) VALUES (?, ?)', [reef_id, room_id]);

        // Commit transaction
        await db.query('COMMIT');

        // Emit socket event
        io.emit('joinReef', { room_id, room_name, reef_id });

        // Log success
        console.log(`✅ Team created successfully: ${room_name} (${room_id})`);
        // here we do 

        res.json({ 
            message: '✅ Team and Reef created successfully', 
            room_id, 
            reef_id 
        });
    } catch (err) {
        // Rollback transaction on error
        await db.query('ROLLBACK');
        console.error('❌ Team creation error:', err);
        res.status(500).json({ error: err.message });
    }
});

// ✅ LIST TEAMS
router.get('/', (req, res) => {
    db.query(`
        SELECT teams.room_id, teams.room_name, COUNT(team_members.user_id) AS member_count
        FROM teams
        LEFT JOIN team_members ON teams.room_id = team_members.room_id
        GROUP BY teams.room_id, teams.room_name;
    `, (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json({ teams: results });
    });
});

// ✅ JOIN TEAM (REAL TIME UPDATE)
router.post('/join', async (req, res) => {
    const { room_id, user_id } = req.body;
    if (!room_id || !user_id) {
        return res.status(400).json({ error: 'Room ID and user ID required' });
    }

    try {
        // Start transaction
        await db.query('START TRANSACTION');

        // Check if team exists
        const [teamsResult] = await db.query('SELECT * FROM teams WHERE room_id = ?', [room_id]);
        if (!teamsResult || teamsResult.length === 0) {
            await db.query('ROLLBACK');
            return res.status(404).json({ error: 'Team not found' });
        }

        // Check if user is already a member
        const [existingMembersResult] = await db.query(
            'SELECT * FROM team_members WHERE room_id = ? AND user_id = ?',
            [room_id, user_id]
        );

        if (existingMembersResult && existingMembersResult.length > 0) {
            await db.query('ROLLBACK');
            return res.status(400).json({ error: 'User is already a member of this team' });
        }

        // Add user to team
        await db.query(
            'INSERT INTO team_members (room_id, user_id) VALUES (?, ?)',
            [room_id, user_id]
        );

        // Get user details for notification
        const [usersResult] = await db.query(
            'SELECT name FROM users WHERE user_id = ?',
            [user_id]
        );

        const userName = usersResult && usersResult[0]?.name || 'User Joined with ID : ';

        // Commit transaction
        await db.query('COMMIT');

        // Emit socket events
        io.to(room_id).emit('teamUpdated', {
            teamId: room_id,
            userId: user_id,
            message: `✅ ${userName} has joined the team!`
        });

        // Get updated team members
        const [membersResult] = await db.query(
            `SELECT team_members.user_id, COALESCE(users.name, 'Unknown') AS name 
             FROM team_members 
             LEFT JOIN users ON team_members.user_id = users.user_id 
             WHERE team_members.room_id = ?`,
            [room_id]
        );

        io.to(room_id).emit('teamMembersUpdated', {
            teamId: room_id,
            members: membersResult || []
        });

        // Log success
        console.log(`✅ User ${userName} (${user_id}) joined team ${room_id}`);

        res.json({ 
            message: '✅ Joined the team successfully',
            teamId: room_id,
            userId: user_id
        });

    } catch (err) {
        // Rollback transaction on error
        await db.query('ROLLBACK');
        console.error('❌ Team join error:', err);
        res.status(500).json({ error: err.message });
    }
});

// ✅ GET TEAM MEMBERS (REAL TIME)
router.get('/members/:room_id', (req, res) => {
    const { room_id } = req.params;

    db.query(
        `SELECT team_members.user_id, COALESCE(users.name, 'Unknown') AS name 
         FROM team_members 
         LEFT JOIN users ON team_members.user_id = users.user_id 
         WHERE team_members.room_id = ?`, 
        [room_id], 
        (err, results) => {
            if (err) return res.status(500).json({ error: err.message });

            // 📌 REAL TIME UPDATE
            io.to(room_id).emit('teamMembersUpdated', { teamId: room_id, members: results });

            res.json({ members: results });
        }
    );
});

// ✅ REMOVE MEMBER FROM THE TEAM (CORRECTED)
router.delete('/remove', (req, res) => {
    const { room_id, user_id } = req.body;
    if (!room_id || !user_id) return res.status(400).json({ error: 'Room ID and user ID required' });

    db.query('DELETE FROM team_members WHERE room_id = ? AND user_id = ?', [room_id, user_id], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        if (results.affectedRows === 0) return res.status(404).json({ error: 'User not found in the team' });

        io.to(room_id).emit('userRemoved', { user_id, room_id, message: `User ${user_id} left the team!` });

        res.json({ message: '✅ User removed from the team' });
    });
});


// ✅ DELETE TEAM
router.delete('/delete', (req, res) => {
    const { room_id } = req.body;
    if (!room_id) return res.status(400).json({ error: 'Room ID is required' });

    db.query('DELETE FROM team_members WHERE room_id = ?', [room_id], (err) => {
        if (err) return res.status(500).json({ error: err.message });

        db.query('DELETE FROM teams WHERE room_id = ?', [room_id], (err, results) => {
            if (err) return res.status(500).json({ error: err.message });
            if (results.affectedRows === 0) return res.status(404).json({ error: 'Team not found' });

            io.emit('teamDeleted', { room_id, message: `Team ${room_id} has been deleted!` });
            res.json({ message: '✅ Team deleted successfully' });
        });
    });
});


// ✅ REEF STATUS OF TEAM
router.get('/reef/:room_id', (req, res) => {
    const { room_id } = req.params;

    db.query('SELECT * FROM team_reefs WHERE room_id = ?', [room_id], (err, reefResults) => {
        if (err) return res.status(500).json({ error: err.message });
        if (reefResults.length === 0) return res.status(404).json({ error: 'Reef not found for this team' });

        db.query('SELECT COUNT(*) AS total_sessions FROM team_pomodoro_sessions WHERE room_id = ?', [room_id], (err, sessionResults) => {
            if (err) return res.status(500).json({ error: err.message });

            res.json({ 
                reef: reefResults[0], 
                total_pomodoro_sessions: sessionResults[0].total_sessions 
            });
        });
    });
});

// ✅ REEF UPDATE OF TEAM
router.post('/reef/update', (req, res) => {
    const { room_id, pollution_change, population_change, growth_change } = req.body;
    if (!room_id) return res.status(400).json({ error: 'Room ID is required' });

    db.query(`
        UPDATE team_reefs 
        SET 
            reef_pollution = reef_pollution + ?, 
            reef_population = reef_population + ?, 
            reef_growth = reef_growth + ?, 
            last_updated = NOW() 
        WHERE room_id = ?`, 
        [pollution_change, population_change, growth_change, room_id], 
        (err, results) => {
            if (err) return res.status(500).json({ error: err.message });

            io.to(room_id).emit('reefUpdated', { room_id, pollution_change, population_change, growth_change });

            res.json({ message: '✅ Reef updated successfully' });
        }
    );
});

// ✅ POMODORO COMPLETE FOR TEAMS
router.post('/pomodoro/complete', (req, res) => {
    const { user_id, room_id, duration } = req.body;
    if (!user_id || !room_id || !duration) return res.status(400).json({ error: 'User ID, Room ID, and Duration are required' });

    const session_id = uuidv4();

    // 1️⃣ GET USER NAME AND REEF ID
    db.query('SELECT name FROM users WHERE user_id = ?', [user_id], (err, userResult) => {
        if (err) return res.status(500).json({ error: err.message });
        if (userResult.length === 0) return res.status(404).json({ error: 'User not found' });

        const userName = userResult[0].name;

        // 2️⃣ GET REEF ID
        db.query('SELECT reef_id FROM team_reefs WHERE room_id = ?', [room_id], (err, reefResult) => {
            if (err) return res.status(500).json({ error: err.message });
            if (reefResult.length === 0) return res.status(404).json({ error: 'Reef not found for this team' });

            const reef_id = reefResult[0].reef_id;

            // 3️⃣ SAVE TEAM POMODORO SESSION
            db.query(
                'INSERT INTO team_pomodoro_sessions (session_id, session_duration, room_id, reef_id) VALUES (?, ?, ?, ?)',
                [session_id, duration, room_id, reef_id],
                (err) => {
                    if (err) return res.status(500).json({ error: err.message });

                    // 4️⃣ UPDATE REEF
                    const pollution_change = -0.5;
                    const population_change = 2;
                    const growth_change = 1.5;

                    db.query(
                        'UPDATE team_reefs SET reef_pollution = reef_pollution + ?, reef_population = reef_population + ?, reef_growth = reef_growth + ?, last_updated = NOW() WHERE room_id = ?',
                        [pollution_change, population_change, growth_change, room_id],
                        (err) => {
                            if (err) return res.status(500).json({ error: err.message });

                            // 5️⃣ REAL-TIME MESSAGE
                            const messages = [
                                `🔥 ${userName} just boosted the team's productivity!`,
                                `🚀 ${userName} completed a Pomodoro for the team!`,
                                `🌊 ${userName}'s focus is powering the reef!`,
                                `💪 ${userName} is on fire! Another Pomodoro done!`
                            ];
                            const personalizedMessage = messages[Math.floor(Math.random() * messages.length)];

                            io.to(room_id).emit('teamPomodoroCompleted', {
                                user_id,
                                room_id,
                                message: personalizedMessage
                            });

                            res.json({ message: `✅ ${personalizedMessage}` });
                        }
                    );
                }
            );
        });
    });
});

router.post('/leave', async (req, res) => {
    const { room_id, user_id } = req.body;
    if (!room_id || !user_id) {
        return res.status(400).json({ error: 'Room ID and User ID required' });
    }

    try {
        // Kullanıcıyı takımdan çıkar
        await db.query('DELETE FROM team_members WHERE room_id = ? AND user_id = ?', [room_id, user_id]);

        // İsterseniz socket ile bildirim de gönderebilirsiniz:
        io.to(room_id).emit('userRemoved', { user_id, room_id, message: `User ${user_id} left the team!` });

        res.json({ message: '✅ User left the team successfully' });
    } catch (err) {
        console.error('Error leaving team:', err);
        res.status(500).json({ error: 'Error leaving team' });
    }
});

    return router;
};