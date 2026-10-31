import { defineHexConfig, type HandlerContext } from "@hex/commands"

// Apps where dictation goes to coding agents, so tech homophones are safe to
// fix there and nowhere else.
const TERMINALS: Record<string, true> = { "Rex Beta": true, Ghostty: true, Terminal: true, iTerm2: true }

// After these words, a spoken "slash" starts a path or command and keeps its
// space ("visit slash admin" → "visit /admin"). After any other word it joins
// the two words ("admins slash mods" → "admins/mods").
const PATH_LEADS: Record<string, true> = Object.fromEntries(
  [
    "a", "an", "and", "are", "at", "call", "called", "for", "from", "go", "hit",
    "in", "into", "is", "like", "my", "of", "on", "open", "or", "our", "run",
    "see", "the", "to", "try", "type", "under", "use", "via", "visit", "with",
  ].map((word) => [word, true]),
)

// "at the rate" is how "@" is read aloud, but "at the rate of" and
// "at the rate we're going" are plain English.
const AT_SIGN = /\bat the rate\s+(?!(?:of|at|which|we|we're|it|it's|that|this|they|you|i|he|she|the|a|an|in)\b)(?=\S)/gi

function devSpeech(text: string, context: HandlerContext): string {
  let out = text.replace(AT_SIGN, "@")
  out = out.replace(/(\w)\s+underscore\s+(?=\w)/gi, "$1_")
  out = out.replace(/(\S*)(\s*)\bslash\s+(?=[\w~.@-])/gi, (_match, previous: string, space: string) =>
    previous && space && /\w$/.test(previous) && !Object.hasOwn(PATH_LEADS, previous.toLowerCase())
      ? `${previous}/`
      : `${previous}${space}/`,
  )
  // Parakeet hears "MR to main" as "MR2 main", "Mr. Two Main", or "MR domain".
  out = out.replace(/\b(?:MR|Mr\.?)\s*(?:to|2|two)\s*(?:main|mean)\b/gi, "MR to main")
  out = out.replace(/\b(?:MR|Mr\.?)\s+domain\b/gi, "MR to main")
  out = out.replace(/\b(o)pen and (?=MR\b)/gi, "$1pen an ")
  if (context.application !== undefined && Object.hasOwn(TERMINALS, context.application)) {
    out = out.replace(/\bflu\b/gi, "Flue")
  }
  return out
}

export default defineHexConfig({
  transformations: {
    "dev-speech": {
      name: "Dev speech",
      description: "Spoken @, /, and _ become symbols; fixes \"MR to main\"; Flu → Flue in terminals",
      transform: devSpeech,
    },
  },
})
