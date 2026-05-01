export type CaptureResult = {
  dataUrl: string;
  width: number;
  height: number;
};

export async function captureScreenOnce(): Promise<CaptureResult> {
  if (!navigator.mediaDevices?.getDisplayMedia) {
    throw new Error("Screen capture is not supported in this browser.");
  }

  let stream: MediaStream | null = null;
  try {
    stream = await navigator.mediaDevices.getDisplayMedia({
      video: { frameRate: 1 },
      audio: false,
    });
  } catch (err) {
    throw new Error(
      err instanceof DOMException && err.name === "NotAllowedError"
        ? "Screen capture was cancelled."
        : "Could not start screen capture.",
    );
  }

  try {
    const video = document.createElement("video");
    video.srcObject = stream;
    video.muted = true;
    await video.play();
    // Wait one frame so dimensions are available.
    await new Promise<void>((resolve) => {
      if (video.readyState >= 2) {
        resolve();
      } else {
        video.onloadeddata = () => resolve();
      }
    });

    const width = video.videoWidth;
    const height = video.videoHeight;
    if (!width || !height) {
      throw new Error("Captured frame has no dimensions.");
    }

    const canvas = document.createElement("canvas");
    canvas.width = width;
    canvas.height = height;
    const ctx = canvas.getContext("2d");
    if (!ctx) throw new Error("Canvas context unavailable.");
    ctx.drawImage(video, 0, 0, width, height);

    const dataUrl = canvas.toDataURL("image/png");
    video.pause();
    video.srcObject = null;

    return { dataUrl, width, height };
  } finally {
    // Always stop tracks so the browser stops recording immediately.
    stream?.getTracks().forEach((track) => track.stop());
  }
}
