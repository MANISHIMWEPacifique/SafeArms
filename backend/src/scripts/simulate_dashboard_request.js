const http = require('http');

const PORT = process.env.PORT || 3000;
const HOST = 'localhost';

function post(path, data) {
    return new Promise((resolve, reject) => {
        const options = {
            hostname: HOST,
            port: PORT,
            path: path,
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(data)
            }
        };

        const req = http.request(options, (res) => {
            let body = '';
            res.on('data', (chunk) => body += chunk);
            res.on('end', () => {
                try {
                    const json = JSON.parse(body);
                    resolve(json);
                } catch (e) {
                    resolve({ success: false, message: 'Invalid JSON', raw: body });
                }
            });
        });

        req.on('error', (e) => reject(e));
        req.write(data);
        req.end();
    });
}

function get(path, token) {
    return new Promise((resolve, reject) => {
        const options = {
            hostname: HOST,
            port: PORT,
            path: path,
            method: 'GET',
            headers: {
                'Authorization': `Bearer ${token}`
            }
        };

        const req = http.request(options, (res) => {
            let body = '';
            res.on('data', (chunk) => body += chunk);
            res.on('end', () => {
                try {
                    const json = JSON.parse(body);
                    resolve(json);
                } catch (e) {
                    resolve({ success: false, message: 'Invalid JSON', raw: body });
                }
            });
        });

        req.on('error', (e) => reject(e));
        req.end();
    });
}

(async () => {
    try {
        console.log("Authenticating as admin...");
        const loginData = JSON.stringify({
            username: "admin",
            password: "Admin@123"
        });
        const loginRes = await post('/api/auth/login', loginData);
        
        if (!loginRes.success) {
            console.error("Login failed:", loginRes);
            return;
        }

        const token = loginRes.token;
        console.log("Login successful. Token acquired.");

        console.log("Fetching dashboard stats...");
        const dashboardRes = await get('/api/dashboard', token);

        if (!dashboardRes.success) {
            console.error("Dashboard fetch failed:", dashboardRes);
            return;
        }

        const data = dashboardRes.data;
        console.log("Dashboard response received.");
        console.log("Recent Activities count:", data.recent_activities ? data.recent_activities.length : 'undefined');

        if (data.recent_activities && data.recent_activities.length > 0) {
            console.log("First activity:", data.recent_activities[0]);
        } else {
            console.log("⚠️ No recent activities in response!");
        }

    } catch (e) {
        console.error("Script error:", e);
    }
})();
