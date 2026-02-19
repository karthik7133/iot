const axios = require('axios');

async function testPost() {
    try {
        const response = await axios.post('https://iot-0ts3.onrender.com/data', {
            temperature: 25.5,
            humidity: 45.0,
            moisture: 35,
            precipitation: 0.0,
            motorStatus: 'ON',
            batteryLevel: 99.0,
            savedWater: 0
        });
        console.log('Response Status:', response.status);
        console.log('Response Body:', response.data);
    } catch (error) {
        console.error('Error Status:', error.response ? error.response.status : 'No response');
        console.error('Error Body:', error.response ? error.response.data : error.message);
    }
}

testPost();
