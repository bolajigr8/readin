import { exec } from 'child_process'
import { promisify } from 'util'
import fs from 'fs/promises'

const execAsync = promisify(exec)

const CONVERSION_TIMEOUT_MS = 300_000 // 5 minutes

export class CalibreService {
  /**
   * Convert any supported format to EPUB using Calibre's ebook-convert CLI.
   * Calibre must be installed on the server (see nixpacks.toml).
   */
  async convertToEpub(inputPath: string, outputPath: string): Promise<void> {
    const start = Date.now()
    console.log(
      `[calibre] Starting EPUB conversion: ${inputPath} → ${outputPath}`,
    )

    try {
      await execAsync(`ebook-convert "${inputPath}" "${outputPath}"`, {
        timeout: CONVERSION_TIMEOUT_MS,
      })
      console.log(
        `[calibre] EPUB conversion completed in ${Date.now() - start}ms`,
      )
    } catch (err) {
      const error = err as { stderr?: string; message?: string }
      throw new Error(
        `Calibre EPUB conversion failed: ${error.stderr ?? error.message ?? 'Unknown error'}`,
      )
    }
  }

  /**
   * Convert to HTML — reserved for future TTS text extraction phase.
   */
  async convertToHtml(inputPath: string, outputPath: string): Promise<void> {
    const start = Date.now()
    console.log(
      `[calibre] Starting HTML conversion: ${inputPath} → ${outputPath}`,
    )

    try {
      await execAsync(`ebook-convert "${inputPath}" "${outputPath}"`, {
        timeout: CONVERSION_TIMEOUT_MS,
      })
      console.log(
        `[calibre] HTML conversion completed in ${Date.now() - start}ms`,
      )
    } catch (err) {
      const error = err as { stderr?: string; message?: string }
      throw new Error(
        `Calibre HTML conversion failed: ${error.stderr ?? error.message ?? 'Unknown error'}`,
      )
    }
  }

  /**
   * Delete temp files after conversion — failures are logged but never thrown.
   */
  async cleanupTempFiles(...paths: string[]): Promise<void> {
    await Promise.all(
      paths.map((p) =>
        fs.unlink(p).catch((err: unknown) => {
          console.warn(`[calibre] Could not clean up temp file "${p}":`, err)
        }),
      ),
    )
  }
}

export const calibreService = new CalibreService()
