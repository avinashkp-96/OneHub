import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { randomBytes } from 'crypto';
import { existsSync, mkdirSync, writeFileSync } from 'fs';
import { join, resolve } from 'path';

// Files people upload: request photos and profile photos (public, served by
// GET /uploads/photos/:name) and ID proofs (private, never served). Kept on
// the API server's disk under UPLOAD_DIR (default ./uploads, git-ignored)
// until hosting is decided; move to object storage then.
//
// Names are random, so a photo link cannot be guessed from another. The type
// is read from the file's first bytes, not its name or the header the client
// sends, and only JPEG, PNG and WebP are kept.

export const MAX_UPLOAD_BYTES = 5 * 1024 * 1024;
export const PHOTO_URL_PREFIX = '/api/v1/uploads/photos/';
export const PHOTO_NAME = /^[a-f0-9]{32}\.(jpg|png|webp)$/;

export type UploadedImage = { buffer: Buffer; size: number };

const TYPES: { ext: string; mime: string; matches: (b: Buffer) => boolean }[] = [
  { ext: 'jpg', mime: 'image/jpeg', matches: (b) => b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff },
  {
    ext: 'png',
    mime: 'image/png',
    matches: (b) => b.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])),
  },
  {
    ext: 'webp',
    mime: 'image/webp',
    matches: (b) => b.subarray(0, 4).toString('latin1') === 'RIFF' && b.subarray(8, 12).toString('latin1') === 'WEBP',
  },
];

export function imageType(buffer: Buffer) {
  return TYPES.find((t) => buffer.length >= 12 && t.matches(buffer));
}

@Injectable()
export class UploadsService {
  private readonly root = resolve(process.env.UPLOAD_DIR ?? 'uploads');

  private dir(...parts: string[]) {
    const dir = join(this.root, ...parts);
    mkdirSync(dir, { recursive: true });
    return dir;
  }

  private store(file: UploadedImage | undefined, ...folder: string[]) {
    if (!file || file.size === 0) throw new BadRequestException('choose an image to upload');
    if (file.size > MAX_UPLOAD_BYTES) throw new BadRequestException('image must be 5 MB or smaller');
    const type = imageType(file.buffer);
    if (!type) throw new BadRequestException('only JPEG, PNG or WebP images can be uploaded');
    const name = `${randomBytes(16).toString('hex')}.${type.ext}`;
    writeFileSync(join(this.dir(...folder), name), file.buffer);
    return name;
  }

  /** A public photo; the returned url is what requests and profiles store. */
  savePhoto(file: UploadedImage | undefined) {
    return { url: PHOTO_URL_PREFIX + this.store(file, 'photos') };
  }

  /** A private ID proof. The reference is stored on the provider and is never
   * turned into a link; an admin review will read it from disk. */
  saveIdProof(file: UploadedImage | undefined) {
    return { url: `upload:id-proofs/${this.store(file, 'private', 'id-proofs')}` };
  }

  /** Where a public photo is on disk, with its type, for serving. */
  photoPath(name: string) {
    if (!PHOTO_NAME.test(name)) throw new NotFoundException('photo not found');
    const path = join(this.root, 'photos', name);
    if (!existsSync(path)) throw new NotFoundException('photo not found');
    const ext = name.split('.').pop();
    return { path, mime: TYPES.find((t) => t.ext === ext)!.mime };
  }
}
