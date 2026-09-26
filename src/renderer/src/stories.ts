import johnBurke from './assets/covers/john-burke.jpg'
import mackHopkins from './assets/covers/mack-hopkins.jpg'
import maSanders from './assets/covers/ma-sanders.jpg'
import perryBonner from './assets/covers/perry-bonner.jpg'

export type Story = {
  id: string
  title: string
  cover: string
  /** Cover center (% of the 1920x1080 stage) and tilt, measured from the Figma pull screen. */
  x: string
  y: string
  rotate: string
}

// Videos live in videos/<id>.mp4 at the project root, served as media://videos/<id>.mp4
export const stories: Story[] = [
  { id: 'john-burke', title: 'John Burke, Confederate Spy', cover: johnBurke, x: '26%', y: '73.5%', rotate: '-5deg' },
  { id: 'mack-hopkins', title: 'Mack Hopkins and the Tuskegee Airmen', cover: mackHopkins, x: '47.2%', y: '78%', rotate: '4deg' },
  { id: 'ma-sanders', title: 'The Courage of Ma Sanders', cover: maSanders, x: '65.9%', y: '72.5%', rotate: '-4deg' },
  { id: 'perry-bonner', title: 'Perry Bonner, All American Hero', cover: perryBonner, x: '84.6%', y: '75.5%', rotate: '3.5deg' },
]
