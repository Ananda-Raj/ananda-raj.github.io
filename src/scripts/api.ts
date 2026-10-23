// Calls the site API. CloudFront signs requests to Lambda, which requires the body hash header.
export type Msg = { role: 'user' | 'assistant'; content: string };

export class ApiError extends Error {
  constructor(
    public code: string,
    public status = 0,
  ) {
    super(code);
  }
}

async function sha256(text: string) {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('');
}

export async function post<T>(base: string, path: string, body: unknown): Promise<T> {
  const json = JSON.stringify(body);
  const ctrl = new AbortController();
  const timer = setTimeout(() => ctrl.abort(), 35000);
  try {
    const res = await fetch(base + path, {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-amz-content-sha256': await sha256(json) },
      body: json,
      signal: ctrl.signal,
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) throw new ApiError(data.error || 'server_error', res.status);
    return data as T;
  } catch (err) {
    throw err instanceof ApiError ? err : new ApiError('network');
  } finally {
    clearTimeout(timer);
  }
}

const TEXT: Record<string, string> = {
  rate_limited: "That's a lot of questions in a short time. Please try again later, or send a message instead.",
  busy: 'The assistant is busy right now. Please try again in a few minutes.',
  resting: 'The assistant is resting until next month. The contact form still works.',
  unavailable: "The assistant isn't available right now. The contact form still works.",
  network: "Couldn't reach the assistant. Check your connection and try again.",
  bad_request: "That couldn't be sent. Try something shorter.",
};

export const errorText = (err: unknown) =>
  TEXT[err instanceof ApiError ? err.code : 'network'] ?? 'Something went wrong. Please try again.';

// Plain text with clickable links, built without innerHTML.
export function renderText(el: HTMLElement, text: string) {
  const parts = text.split(/(https?:\/\/[^\s<>()]+[^\s<>().,;:!?'"])/g);
  parts.forEach((part, i) => {
    if (i % 2) {
      const a = document.createElement('a');
      a.href = part;
      a.textContent = part.replace(/^https?:\/\/(www\.)?/, '');
      if (!part.startsWith(location.origin)) {
        a.target = '_blank';
        a.rel = 'noopener';
      }
      el.append(a);
    } else if (part) {
      el.append(part);
    }
  });
}
