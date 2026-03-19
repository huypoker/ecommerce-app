const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const { requireAdmin } = require('../middleware/auth');
const router = express.Router();

const upload = multer({ storage: multer.memoryStorage(), limits: { fileSize: 10 * 1024 * 1024 } });

// Check if Cloudinary is configured
const hasCloudinary = process.env.CLOUDINARY_CLOUD_NAME && process.env.CLOUDINARY_API_KEY && process.env.CLOUDINARY_API_SECRET;
let cloudinary;
if (hasCloudinary) {
  cloudinary = require('cloudinary').v2;
  cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET,
  });
  console.log('☁️  Cloudinary configured for image uploads');
} else {
  console.log('📁 Cloudinary not configured — using local file storage for uploads');
}

router.post('/', requireAdmin, upload.single('image'), async (req, res) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'No image file provided' });

    const allowedTypes = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];
    if (!allowedTypes.includes(req.file.mimetype)) {
      return res.status(400).json({ error: 'Only JPEG, PNG, GIF and WebP images are allowed' });
    }

    let url;

    if (hasCloudinary) {
      // Upload to Cloudinary
      const result = await new Promise((resolve, reject) => {
        cloudinary.uploader.upload_stream({ folder: 'ecommerce' }, (err, result) => {
          if (err) reject(err);
          else resolve(result);
        }).end(req.file.buffer);
      });
      url = result.secure_url;
    } else {
      // Save locally
      const dataDir = process.env.DATA_DIR || process.cwd();
      const uploadsDir = path.join(dataDir, 'uploads');
      if (!fs.existsSync(uploadsDir)) fs.mkdirSync(uploadsDir, { recursive: true });

      const ext = path.extname(req.file.originalname) || '.jpg';
      const filename = `${Date.now()}-${crypto.randomBytes(6).toString('hex')}${ext}`;
      fs.writeFileSync(path.join(uploadsDir, filename), req.file.buffer);
      url = `uploads/${filename}`;
    }

    res.status(201).json({ url });
  } catch (e) {
    res.status(500).json({ error: `Upload failed: ${e.message}` });
  }
});

module.exports = router;
