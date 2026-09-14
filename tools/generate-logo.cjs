// Rasterize the original vector mark and pack PNG frames into a Windows ICO.
// Usage: NODE_PATH=<directory containing sharp> node tools/generate-logo.cjs
const fs = require('node:fs');
const path = require('node:path');
const sharp = require('sharp');
async function main() {
    const resources = path.resolve(__dirname, '../res');
    const source = path.join(resources, 'sakura-mark.svg');
    await sharp(source).resize(256, 256).png().toFile(path.join(resources, 'sakura-mark.png'));
    const sizes = [16, 24, 32, 48, 64, 128, 256];
    const frames = await Promise.all(sizes.map(size => sharp(source).resize(size, size).png().toBuffer()));
    const header = Buffer.alloc(6 + sizes.length * 16);
    header.writeUInt16LE(1, 2); header.writeUInt16LE(sizes.length, 4);
    let offset = header.length;
    frames.forEach((frame, index) => {
        const at = 6 + index * 16;
        header[at] = header[at + 1] = sizes[index] === 256 ? 0 : sizes[index];
        header.writeUInt16LE(1, at + 4); header.writeUInt16LE(32, at + 6);
        header.writeUInt32LE(frame.length, at + 8); header.writeUInt32LE(offset, at + 12);
        offset += frame.length;
    });
    fs.writeFileSync(path.join(resources, 'sakura-mark.ico'), Buffer.concat([header, ...frames]));
}
main().catch(error => { console.error(error); process.exitCode = 1; });
