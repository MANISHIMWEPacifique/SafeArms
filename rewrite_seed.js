const fs = require('fs');
const path = 'backend/src/scripts/seedDatabase.js';
let content = fs.readFileSync(path, 'utf8');

// We will replace the FIREARMs, BALLISTIC PROFILES, and MOVEMENTS sections 
// with a more dynamic generator that ensures every unit gets exactly 5 firearms (mostly AK-47s).

content = content.replace(/\/\/ Nyamirambo Station Firearms.*?console\.log\('  \[OK\] 2 firearms reserved at HQ \(UNIT-HQ\)'\);/s, `
    const units = ['UNIT-NYA', 'UNIT-KIM', 'UNIT-REM', 'UNIT-KIC', 'UNIT-PTS', 'UNIT-HQ'];
    
    // Generate 5 firearms per unit (1 Glock, 4 AK-47s)
    let faCount = 1;
    for (const unit of units) {
      const inserts = [];
      for (let i = 1; i <= 5; i++) {
        const faId = \`FA-\${faCount.toString().padStart(3, '0')}\`;
        const isAK = i > 1; // 1st is Glock, rest are AK-47
        const model = isAK ? 'AK-47' : 'Glock 17 Gen5';
        const manufacturer = isAK ? 'Kalashnikov' : 'Glock';
        const type = isAK ? 'rifle' : 'pistol';
        const caliber = isAK ? '7.62x39mm' : '9mm';
        const sn = isAK ? \`AK-\${unit.replace('UNIT-', '')}-\${i.toString().padStart(4, '0')}\` : \`GLK-\${unit.replace('UNIT-', '')}-\${i.toString().padStart(4, '0')}\`;
        
        inserts.push(\`('\${faId}', '\${sn}', '\${manufacturer}', '\${model}', '\${type}', '\${caliber}', 2020, '2020-01-15', 'Government Procurement', 'hq', 'USR-002', '\${unit}', 'available', true)\`);
        
        faCount++;
      }
      
      await client.query(\`
        INSERT INTO firearms (firearm_id, serial_number, manufacturer, model, firearm_type, caliber, manufacture_year, acquisition_date, acquisition_source, registration_level, registered_by, assigned_unit_id, current_status, is_active)
        VALUES \${inserts.join(', ')}
      \`);
      console.log(\`  [OK] 5 firearms assigned to \${unit}\`);
    }
`);

content = content.replace(/\/\/ Dynamic additional firearms if requested by arguments e\.g\., node seedDatabase\.js 50.*?\/\/ ============================================/s, `// Dynamic additional firearms if requested by arguments e.g., node seedDatabase.js 50
    const desiredTotal = parseInt(process.argv[2], 10);
    if (!isNaN(desiredTotal) && desiredTotal > 30) {
      const extraCount = desiredTotal - 30;
      console.log(\`\\n[SEED] Generating \${extraCount} additional firearms as requested...\`);
      const extraValues = [];
      for (let i = 1; i <= extraCount; i++) {
        const faIdNumber = 30 + i;
        const faId = \`FA-\${faIdNumber.toString().padStart(3, '0')}\`;
        const sn = \`GEN-EXT-\${faIdNumber.toString().padStart(4, '0')}\`;
        extraValues.push(\`('\${faId}', '\${sn}', 'Kalashnikov', 'AK-47', 'rifle', '7.62x39mm', 2024, '2024-01-01', 'Government Procurement', 'hq', 'USR-002', 'UNIT-HQ', 'available', true)\`);
      }
      
      for (let i = 0; i < extraValues.length; i += 100) {
        const batch = extraValues.slice(i, i + 100);
        await client.query(\`
          INSERT INTO firearms (firearm_id, serial_number, manufacturer, model, firearm_type, caliber, manufacture_year, acquisition_date, acquisition_source, registration_level, registered_by, assigned_unit_id, current_status, is_active)
          VALUES \${batch.join(', ')}
        \`);
      }
      console.log(\`  [OK] \${extraCount} additional firearms generated at HQ (UNIT-HQ)\`);
      faCount += extraCount;
    }

    // ============================================
`);


content = content.replace(/await client\.query\(\`\s+INSERT INTO ballistic_profiles.*?\(\'BP-004.*?\'USR-008\'\)\s+\`\);\s+console\.log\(\'\[OK\] 4 ballistic profiles seeded\'\);/s, `
    let bpInserts = [];
    // faCount now holds total firearms created + 1
    for (let i = 1; i < faCount; i++) {
      const faId = \`FA-\${i.toString().padStart(3, '0')}\`;
      const bpId = \`BP-\${i.toString().padStart(3, '0')}\`;
      const isRifle = i % 5 !== 1; // Simplistic but matches our manual generation where 1st of 5 is Glock
      const rifling = isRifle ? '4 grooves, right-hand twist, 1:9.45 pitch' : '6 grooves, right-hand twist, 1:10 pitch';
      
      bpInserts.push(\`('\${bpId}', '\${faId}', '2023-01-10', 'RNP Forensic Laboratory', '\${rifling}', 'Circular, centered, 0.8mm diameter', 'Semi-circular', 'Dr. Kamanzi Eric', 'RNP Central Forensic Lab', 'USR-008')\`);
      
      if (bpInserts.length === 50) {
        await client.query(\`
          INSERT INTO ballistic_profiles (ballistic_id, firearm_id, test_date, test_location, rifling_characteristics, firing_pin_impression, ejector_marks, test_conducted_by, forensic_lab, created_by)
          VALUES \${bpInserts.join(', ')}
        \`);
        bpInserts = [];
      }
    }
    
    if (bpInserts.length > 0) {
      await client.query(\`
        INSERT INTO ballistic_profiles (ballistic_id, firearm_id, test_date, test_location, rifling_characteristics, firing_pin_impression, ejector_marks, test_conducted_by, forensic_lab, created_by)
        VALUES \${bpInserts.join(', ')}
      \`);
    }
    console.log(\`  [OK] \${faCount - 1} ballistic profiles seeded\`);
`);

content = content.replace(/await client\.query\(\`\s+INSERT INTO firearm_unit_movements.*?\'MOV-012\'.*?\'HQ reserve stock\'\)\s+\`\);/s, `
    let movInserts = [];
    let currentUnitIdx = 0;
    const allUnits = ['UNIT-NYA', 'UNIT-KIM', 'UNIT-REM', 'UNIT-KIC', 'UNIT-PTS', 'UNIT-HQ'];
    
    for (let i = 1; i < faCount; i++) {
      const faId = \`FA-\${i.toString().padStart(3, '0')}\`;
      const movId = \`MOV-\${i.toString().padStart(3, '0')}\`;
      
      // Determine unit (First 30 are distributed 5 each to the 6 units. The rest are HQ)
      let targetUnit = 'UNIT-HQ';
      if (i <= 30) {
         targetUnit = allUnits[Math.floor((i - 1) / 5)];
      }

      movInserts.push(\`('\${movId}', '\${faId}', NULL, '\${targetUnit}', 'initial_assignment', 'USR-002', 'Initial firearm registration and assignment')\`);
      
      if (movInserts.length === 100) {
         await client.query(\`
           INSERT INTO firearm_unit_movements (movement_id, firearm_id, from_unit_id, to_unit_id, movement_type, authorized_by, reason)
           VALUES \${movInserts.join(', ')}
         \`);
         movInserts = [];
      }
    }
    
    if (movInserts.length > 0) {
       await client.query(\`
         INSERT INTO firearm_unit_movements (movement_id, firearm_id, from_unit_id, to_unit_id, movement_type, authorized_by, reason)
         VALUES \${movInserts.join(', ')}
       \`);
    }
`);

fs.writeFileSync(path, content, 'utf8');
