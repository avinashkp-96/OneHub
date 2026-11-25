import { Controller, Get, Param, Post, Res, UploadedFile, UseGuards, UseInterceptors } from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { MAX_UPLOAD_BYTES, UploadedImage, UploadsService } from './uploads.service';

// The file arrives as multipart field "file" and is held in memory (multer's
// default with no destination) until the service checks and writes it. The
// size limit is enforced while reading, so a larger upload is cut off (413)
// rather than held whole.
const oneImage = () => FileInterceptor('file', { limits: { fileSize: MAX_UPLOAD_BYTES, files: 1 } });

@Controller('uploads')
export class UploadsController {
  constructor(private readonly uploads: UploadsService) {}

  // Request photos and profile photos; signed-in users only.
  @UseGuards(JwtAuthGuard)
  @Post('photo')
  @UseInterceptors(oneImage())
  photo(@UploadedFile() file: UploadedImage) {
    return this.uploads.savePhoto(file);
  }

  // ID proof. Open to anyone because provider signup needs it before the
  // account exists; the file is private and never served. Needs rate limiting
  // before the API is public.
  @Post('id-proof')
  @UseInterceptors(oneImage())
  idProof(@UploadedFile() file: UploadedImage) {
    return this.uploads.saveIdProof(file);
  }

  // Public, so the apps can show photos with a plain image request. Names are
  // random and immutable, so they can be cached for a long time.
  @Get('photos/:name')
  servePhoto(
    @Param('name') name: string,
    @Res() res: { setHeader(k: string, v: string): void; sendFile(path: string): void },
  ) {
    const { path, mime } = this.uploads.photoPath(name);
    res.setHeader('Content-Type', mime);
    res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.sendFile(path);
  }
}
