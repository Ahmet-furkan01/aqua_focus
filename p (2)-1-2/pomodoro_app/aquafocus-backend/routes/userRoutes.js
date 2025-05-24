const express = require('express');
const db = require('../db');
const { v4: uuidv4 } = require('uuid');
const bcrypt = require('bcryptjs');

const saltRounds = 10;

module.exports = (io) => {
    const router = express.Router();

// ✅ USER REGISTER
router.post('/register', async (req, res) => {
        const { name, email, password } = req.body;
    const user_id = uuidv4();
        
        if (!name || !email || !password) {
            return res.status(400).json({ error: 'All fields are required' });
        }

    try {
            const hashedPassword = await bcrypt.hash(password, saltRounds);

        db.query(
                'INSERT INTO users (user_id, name, email, password_hash) VALUES (?, ?, ?, ?)', 
                [user_id, name, email, hashedPassword], 
                (err) => {
                    if (err) return res.status(500).json({ error: err.message });

                    const reef_id = uuidv4();
                    db.query(
                        'INSERT INTO reefs (reef_id, user_id) VALUES (?, ?)', 
                        [reef_id, user_id], 
                        (err) => {
                            if (err) return res.status(500).json({ error: err.message });
                            res.json({ 
                                message: '✅ User registered successfully', 
                                user_id, 
                                reef_id
                });
            }
        );
                }
            );
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// ✅ USER LOGIN
router.post('/login', (req, res) => {
    const { email, password } = req.body;
        
        if (!email || !password) {
            return res.status(400).json({ error: 'Email and password are required' });
        }

        db.query(
            'SELECT * FROM users WHERE email = ?', 
            [email], 
            async (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        if (results.length === 0) return res.status(404).json({ error: 'User not found' });

        const user = results[0];
        const isPasswordValid = await bcrypt.compare(password, user.password_hash);
                
                if (!isPasswordValid) {
                    return res.status(401).json({ error: 'Invalid password' });
                }

                res.json({ 
                    message: '✅ Login successful', 
                    user_id: user.user_id 
                });
            }
        );
});

// ✅ LIST OF USERS
router.get('/users', (req, res) => {
    db.query('SELECT user_id, name, email FROM users', (err, results) => {
        if (err) return res.status(500).json({ error: err.message });
        res.json({ users: results });
    });
});

// ✅ REEF STATUS OF USER
router.get('/reef/:user_id', (req, res) => {
    const { user_id } = req.params;

        db.query('SELECT * FROM reefs WHERE user_id = ?', [user_id], (err, results) => {
        if (err) return res.status(500).json({ error: err.message });

        if (results.length === 0) {
            return res.status(404).json({ message: 'Reef not found for this user' });
        }

        res.json({ reef: results[0] });
    });
});

// ✅ POMODORO COMPLETE (USER)
router.post('/pomodoro/complete', (req, res) => {
    const { user_id, duration } = req.body;
    if (!user_id || !duration) return res.status(400).json({ error: 'User ID and Duration are required' });

    const session_id = uuidv4();
    const now = new Date();

    // 1️⃣ GET USER NAME
    db.query('SELECT name FROM users WHERE user_id = ?', [user_id], (err, userResult) => {
        if (err) return res.status(500).json({ error: err.message });
        if (userResult.length === 0) return res.status(404).json({ error: 'User not found' });

        const userName = userResult[0].name;

        // 2️⃣ REEF CONTROL
        db.query('SELECT * FROM reefs WHERE user_id = ?', [user_id], (err, reefResults) => {
            if (err) return res.status(500).json({ error: err.message });

            const reef_id = reefResults.length > 0 ? reefResults[0].reef_id : uuidv4();

            if (reefResults.length === 0) {
                db.query('INSERT INTO reefs (reef_id, user_id) VALUES (?, ?)', [reef_id, user_id], (err) => {
                    if (err) return res.status(500).json({ error: '❌ Error creating reef for user.' });
                });
            }

            // 3️⃣ ADD POMODORO SESSION
            db.query(
                'INSERT INTO pomodoro_sessions (session_id, user_id, reef_id, session_duration, break_duration, focus_level, productivity_score, session_start, session_end) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
                [
                    session_id,
                    user_id,
                    reef_id,
                    duration,  // session_duration
                    5,        // break_duration (default 5 minutes)
                    8,        // focus_level (default 8/10)
                    85,       // productivity_score (default 85%)
                    now,      // session_start
                    new Date(now.getTime() + duration * 60000)  // session_end (duration minutes later)
                ],
                (err) => {
                    if (err) {
                        console.error('Pomodoro session error:', err);
                        return res.status(500).json({ error: err.message });
                    }

                    // 4️⃣ SEND SUCCESS MESSAGE
                    const message = `✅ Pomodoro session completed successfully!`;
                    res.json({ 
                        message, 
                        session_id,
                        reef_id,
                        duration: duration,
                        start_time: now,
                        end_time: new Date(now.getTime() + duration * 60000)
                    });
                }
            );
        });
    });
});

    // ✅ USER PROFILE
    router.get('/users/profile/:user_id', (req, res) => {
        const { user_id } = req.params;

        db.query('SELECT user_id, name, email FROM users WHERE user_id = ?', [user_id], (err, results) => {
                    if (err) return res.status(500).json({ error: err.message });
            if (results.length === 0) return res.status(404).json({ error: 'User not found' });

            res.json({ 
                message: '✅ User profile retrieved successfully',
                user: results[0]
            });
        });
    });

    router.get('/users/reef/:userId', async (req, res) => {
        try {
            const { userId } = req.params;
            const query = 'SELECT * FROM reefs WHERE user_id = ?';
            
            db.query(query, [userId], (err, results) => {
                if (err) {
                    console.error('Error fetching user reef:', err);
                    return res.status(500).json({ error: 'Database error' });
                }
                
                if (results.length === 0) {
                    return res.status(404).json({ error: 'Reef not found' });
                }
                
                res.json(results[0]);
            });
        } catch (error) {
            console.error('Error in /users/reef/:userId:', error);
            res.status(500).json({ error: 'Server error' });
        }
    });

    // ✅ USER ACHIEVEMENTS
    router.get('/user_achievements/:userId', (req, res) => {
        const { userId } = req.params;
        const query = `
            SELECT a.achievement_id, a.name as achievement_name, a.description,
                   CASE WHEN ua.user_id IS NOT NULL THEN true ELSE false END as is_achieved,
                   ua.achieved_at
            FROM achievements a
            LEFT JOIN user_achievements ua ON a.achievement_id = ua.achievement_id AND ua.user_id = ?
        `;
        
        db.query(query, [userId], (err, results) => {
            if (err) {
                console.error('Error fetching user achievements:', err);
                return res.status(500).json({ error: 'Database error' });
            }
            
            res.json({ 
                message: '✅ User achievements retrieved successfully',
                achievements: results 
            });
        });
    });

    // ✅ USER STATISTICS
    router.get('/user_statistics/:userId', async (req, res) => {
        const { userId } = req.params;

        try {
            // Get user statistics
            const [stats] = await db.promise().query(`
                SELECT *
                FROM user_statistics
                WHERE user_id = ?
            `, [userId]);

            // Get today's pomodoro sessions
            const [todaySessions] = await db.promise().query(`
                SELECT 
                    SUM(session_duration) AS total_focus_time,
                    COUNT(*) AS session_count
                FROM pomodoro_sessions
                WHERE user_id = ?
                    AND session_start >= CURDATE()
                    AND session_start < CURDATE() + INTERVAL 1 DAY
            `, [userId]);

            // Calculate focus rate
            const totalFocusTime = todaySessions[0]?.total_focus_time || 0;
            const totalAppTime = (todaySessions[0]?.session_count || 0) * 25;
            const focusRate = totalAppTime > 0 ? Math.round((totalFocusTime / totalAppTime) * 100) : 0;

            // Update user statistics with focus rate
            if (stats.length > 0) {
                await db.promise().query(`
                    UPDATE user_statistics
                    SET avg_productivity_score = ?, avg_focus_level = ?
                    WHERE user_id = ?
                `, [focusRate, 8, userId]);
            }

            // Return statistics
            const statistics = stats.length > 0 ? {
                total_pomodoros: stats[0].completed_pomodoros,
                total_duration: null,
                completed_tasks: stats[0].total_tasks_completed,
                streak_days: null,
                last_activity_date: stats[0].date,
                focus_rate: focusRate
            } : {
                total_pomodoros: 0,
                total_duration: 0,
                completed_tasks: 0,
                streak_days: 0,
                last_activity_date: null,
                focus_rate: 0
            };

            res.json({ 
                message: '✅ User statistics retrieved successfully',
                statistics: statistics
            });
        } catch (err) {
            console.error('Error fetching user statistics:', err);
            res.status(500).json({ error: 'Database error' });
        }
    });

    // ✅ GET ALL TASKS
    router.get('/tasks', (req, res) => {
        const query = 'SELECT * FROM tasks';
        
        db.query(query, (err, results) => {
            if (err) {
                console.error('Error fetching tasks:', err);
                return res.status(500).json({ error: 'Database error' });
            }
            
            res.json({ 
                message: '✅ Tasks retrieved successfully',
                tasks: results 
            });
        });
    });

    // ✅ GET USER TASKS
    router.get('/user_tasks/:userId', (req, res) => {
        const { userId } = req.params;
        const query = `
            SELECT 
                user_id,
                task_id,
                status,
                completed_at,
                created_at,
                task_type,
                description
            FROM user_tasks
            WHERE user_id = ?
        `;
        db.query(query, [userId], (err, results) => {
            if (err) {
                return res.status(500).json({ error: 'Database error' });
            }
            res.json({ 
                message: '✅ User tasks retrieved successfully',
                user_tasks: results 
            });
        });
    });

    // ✅ GET ALL CREATURES
    router.get('/creatures', (req, res) => {
        const query = 'SELECT * FROM creatures';
        
        db.query(query, (err, results) => {
            if (err) {
                console.error('Error fetching creatures:', err);
                return res.status(500).json({ error: 'Database error' });
            }
            
            res.json({ 
                message: '✅ Creatures retrieved successfully',
                creatures: results 
            });
        });
    });

    // ✅ GET USER CREATURES
    router.get('/user_creatures/:userId', (req, res) => {
        const { userId } = req.params;
        const query = `
            SELECT 
                c.*,
                CASE WHEN uc.user_id IS NOT NULL THEN true ELSE false END as is_owned,
                uc.obtained_at
            FROM creatures c
            LEFT JOIN user_creatures uc ON c.creature_id = uc.creature_id AND uc.user_id = ?
        `;

        db.query(query, [userId], (err, results) => {
            if (err) {
                console.error('Database error:', err);
                return res.status(500).json({ error: 'Database error', details: err.message });
            }
            res.json({ creatures: results });
        });
    });

    // ✅ GET TASK CREATURES
    router.get('/task_creatures/:taskId', (req, res) => {
        const { taskId } = req.params;
        const query = `
            SELECT 
                c.*
            FROM creatures c
            INNER JOIN task_creatures tc ON c.creature_id = tc.creature_id
            WHERE tc.task_id = ?
        `;

        db.query(query, [taskId], (err, results) => {
            if (err) {
                console.error('Database error:', err);
                return res.status(500).json({ error: 'Database error', details: err.message });
            }
            res.json({ creatures: results });
        });
});
router.get('/stats/:userId', async (req, res) => {
    const { userId } = req.params;
  
    try {
      // Daily focus time (today, by 2-hour intervals)
      const [daily] = await db.promise().query(`
        SELECT
          HOUR(session_start) DIV 2 AS block,
          SUM(session_duration) AS total_minutes,
          COUNT(*) AS session_count,
          SUM(session_duration) AS total_focus_time,
          COUNT(*) * 25 AS total_app_time
        FROM pomodoro_sessions
        WHERE user_id = ?
          AND session_start >= CURDATE()
          AND session_start < CURDATE() + INTERVAL 1 DAY
        GROUP BY block
      `, [userId]);
  
      const dailyStats = daily.map(item => ({
        ...item,
        total_minutes: parseInt(item.total_minutes),
        focus_rate: item.total_app_time > 0 ? 
          Math.round((item.total_focus_time / item.total_app_time) * 100) : 0
      }));
  
      // Weekly focus time (last 7 full days including today)
      const [weekly] = await db.promise().query(`
        SELECT
          DATE(session_start) AS date,
          MOD(DAYOFWEEK(session_start) + 5, 7) + 1 AS day,
          SUM(session_duration) AS total_minutes,
          COUNT(*) AS session_count,
          SUM(session_duration) AS total_focus_time,
          COUNT(*) * 25 AS total_app_time
        FROM pomodoro_sessions
        WHERE user_id = ?
          AND session_start >= CURDATE() - INTERVAL 6 DAY
          AND session_start < CURDATE() + INTERVAL 1 DAY
        GROUP BY date, day
      `, [userId]);
  
      const weeklyStats = weekly.map(item => ({
        ...item,
        total_minutes: parseInt(item.total_minutes),
        focus_rate: item.total_app_time > 0 ? 
          Math.round((item.total_focus_time / item.total_app_time) * 100) : 0
      }));

      // Calculate overall focus rate
      const totalFocusTime = daily.reduce((sum, item) => sum + item.total_focus_time, 0);
      const totalAppTime = daily.reduce((sum, item) => sum + item.total_app_time, 0);
      const overallFocusRate = totalAppTime > 0 ? Math.round((totalFocusTime / totalAppTime) * 100) : 0;
  
      res.json({ 
        daily: dailyStats, 
        weekly: weeklyStats,
        focus_rate: overallFocusRate
      });
    } catch (err) {
      console.error(err);
      res.status(500).json({ error: "Failed to load stats" });
    }
  });


router.post('/pomodoro/session', (req, res) => {
      const {
          user_id,
          reef_id,
          session_duration,
          break_duration,
          productivity_score,
          focus_level,
          session_start,
          session_end
      } = req.body;

      if (!user_id || !reef_id || !session_duration || !break_duration || !session_start || !session_end) {
          return res.status(400).json({ error: 'Missing required fields' });
      }

      const session_id = uuidv4();
      
      // Calculate focus rate for this session
      const totalFocusTime = session_duration;
      const totalAppTime = 25; // Standard pomodoro duration
      const focusRate = Math.round((totalFocusTime / totalAppTime) * 100);

      // Insert session with survey results
      db.query(
          'INSERT INTO pomodoro_sessions (session_id, user_id, reef_id, session_duration, break_duration, productivity_score, focus_level, session_start, session_end, focus_rate) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [session_id, user_id, reef_id, session_duration, break_duration, productivity_score, focus_level, session_start, session_end, focusRate],
          (err) => {
              if (err) return res.status(500).json({ error: err.message });

              // Update user statistics
              db.query(
                  'UPDATE user_statistics SET avg_productivity_score = ?, avg_focus_level = ? WHERE user_id = ?',
                  [productivity_score, focus_level, user_id],
                  (err) => {
                      if (err) return res.status(500).json({ error: err.message });
                      res.json({ message: '✅ Pomodoro session saved successfully' });
                  }
              );
          }
      );
});

// ✅ CREATE USER TASK
router.post('/user_tasks', (req, res) => {
    const { user_id, description, task_type } = req.body;
    if (!user_id || !description || !task_type) {
        return res.status(400).json({ error: 'user_id, description, and task_type are required' });
    }
    const task_id = uuidv4();
    const created_at = new Date();
    db.query(
        'INSERT INTO user_tasks (user_id, task_id, description, task_type, status, created_at) VALUES (?, ?, ?, ?, ?, ?)',
        [user_id, task_id, description, task_type, 'pending', created_at],
        (err) => {
            if (err) {
                return res.status(500).json({ error: 'Database error', details: err.message });
            }
            res.json({ message: '✅ Task created successfully', task_id });
        }
    );
});

// ✅ MARK USER TASK AS COMPLETED (POST version)
router.post('/user_tasks/complete', (req, res) => {
    const { user_id, task_id } = req.body;
    if (!user_id || !task_id) {
        return res.status(400).json({ error: 'user_id and task_id are required' });
    }
    const completed_at = new Date();
    db.query(
        'UPDATE user_tasks SET status = ?, completed_at = ? WHERE user_id = ? AND task_id = ?',
        ['completed', completed_at, user_id, task_id],
        (err, result) => {
            if (err) {
                return res.status(500).json({ error: 'Database error', details: err.message });
            }
            if (result.affectedRows === 0) {
                return res.status(404).json({ error: 'Task not found' });
            }
            res.json({ message: '✅ Task marked as completed' });
        }
    );
});

// ✅ DELETE USER TASK
router.delete('/user_tasks', (req, res) => {
    const { user_id, task_id } = req.body;
    if (!user_id || !task_id) {
        return res.status(400).json({ error: 'user_id and task_id are required' });
    }
    db.query(
        'DELETE FROM user_tasks WHERE user_id = ? AND task_id = ?',
        [user_id, task_id],
        (err, result) => {
            if (err) {
                return res.status(500).json({ error: 'Database error', details: err.message });
            }
            if (result.affectedRows === 0) {
                return res.status(404).json({ error: 'Task not found' });
            }
            res.json({ message: '✅ Task deleted successfully' });
        }
    );
});

// Add new endpoint for updating user statistics
router.post('/user_statistics/update', (req, res) => {
    const { user_id, productivity_score, focus_level } = req.body;

    if (!user_id || !productivity_score || !focus_level) {
        return res.status(400).json({ error: 'Missing required fields' });
    }

    // First, check if the table exists and create it if it doesn't
    db.query(`
        CREATE TABLE IF NOT EXISTS user_statistics (
            user_id VARCHAR(36) PRIMARY KEY,
            avg_productivity_score INT,
            avg_focus_level INT,
            focus_rate INT,
            completed_pomodoros INT DEFAULT 0,
            total_tasks_completed INT DEFAULT 0,
            date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(user_id)
        )
    `, (err) => {
        if (err) return res.status(500).json({ error: err.message });

        // Then update the statistics
        db.query(
            'INSERT INTO user_statistics (user_id, avg_productivity_score, avg_focus_level) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE avg_productivity_score = ?, avg_focus_level = ?',
            [user_id, productivity_score, focus_level, productivity_score, focus_level],
            (err) => {
                if (err) return res.status(500).json({ error: err.message });
                res.json({ message: '✅ User statistics updated successfully' });
            }
        );
    });
});

// Add endpoint to update survey results for a pomodoro session
router.post('/pomodoro/session/survey', (req, res) => {
    const { session_id, productivity_score, focus_level } = req.body;
    if (!session_id || productivity_score == null || focus_level == null) {
        return res.status(400).json({ error: 'Missing required fields' });
    }
    db.query(
        'UPDATE pomodoro_sessions SET productivity_score = ?, focus_level = ? WHERE session_id = ?',
        [productivity_score, focus_level, session_id],
        (err, result) => {
            if (err) return res.status(500).json({ error: err.message });
            if (result.affectedRows === 0) return res.status(404).json({ error: 'Session not found' });
            res.json({ message: '✅ Survey results saved to session!' });
        }
    );
});

    return router;
};