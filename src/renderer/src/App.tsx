import { useEffect, useState, type CSSProperties } from 'react'
import { stories, type Story } from './stories'

export function App() {
  const [story, setStory] = useState<Story | null>(null)

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => e.key === 'Escape' && setStory(null)
    document.addEventListener('keydown', onKey)
    return () => document.removeEventListener('keydown', onKey)
  }, [])

  return (
    <main className="stage">
      <section className="pullscreen" aria-label="Select a story">
        {stories.map((s) => (
          <button
            key={s.id}
            className="cover"
            style={{ '--x': s.x, '--y': s.y, '--r': s.rotate } as CSSProperties}
            onClick={() => setStory(s)}
          >
            <img src={s.cover} alt={s.title} />
          </button>
        ))}
      </section>

      {story && <StoryVideo key={story.id} story={story} onDone={() => setStory(null)} />}
    </main>
  )
}

function StoryVideo({ story, onDone }: { story: Story; onDone: () => void }) {
  const [revealed, setRevealed] = useState(false)
  const src = `media://videos/${story.id}.mp4`

  return (
    <video
      className={`story ${revealed ? 'revealed' : 'revealing'}`}
      src={src}
      preload="auto"
      playsInline
      // The story only starts once the burst transition has fully revealed it.
      onAnimationEnd={(e) => {
        setRevealed(true)
        e.currentTarget.play()
      }}
      onEnded={onDone}
      // Staff can mouse-click out of a story; visitors' touches (and pens) are ignored.
      onPointerUp={(e) => e.pointerType === 'mouse' && onDone()}
      onError={() => {
        console.error(`Could not load ${src}`)
        onDone()
      }}
    />
  )
}
