# Blueprint: Evo-Quest

## Overview

Evo-Quest is a quest-based chore and task management application designed to help children, particularly those with ADHD and executive dysfunction, build routines and complete tasks in an engaging way. The app uses a gamified "evolution" theme where completing chores (Quests) earns experience points (XP), allowing a virtual creature to "evolve."

This approach aims to provide motivation, immediate feedback, and a clear sense of progress, transforming mundane tasks into a rewarding game.

## Design & Style Guide

The application will be designed with a strong focus on accessibility and user engagement, tailored to its target audience.

-   **Theme:** A vibrant, nature-inspired theme that feels adventurous and fun.
-   **Aesthetics:** A clean, uncluttered, and visually balanced layout to minimize distractions. Components will be modern and intuitive.
-   **Fonts:** The `google_fonts` package will be used to implement a highly readable yet playful font, such as "Nunito" or "Poppins."
-   **Color Palette:** A cohesive and energetic color palette will be generated using Material 3's `ColorScheme.fromSeed`, with earthy tones and bright accents for rewards.
-   **Iconography:** Clear and simple icons will be used to represent quests, creatures, and rewards.
-   **Interactivity & Feedback:** Interactive elements like checkboxes and buttons will have a satisfying "glow" or animation. Progress, like gaining XP, will be visualized instantly with animated progress bars.
-   **Images:** The app will feature illustrations of creatures that evolve over time. Initially, these will be placeholder images.

## Core Features & Current Plan

### Phase 1: Core Mechanics and UI

The initial development will focus on building the main user experience and core logic.

1.  **Data Models:**
    *   Create a `Quest` class to define a chore, including its title, description, XP value, and completion status.
    *   Create a `Creature` class to manage the user's evolving creature, tracking its name, level, current XP, and evolution stage.
2.  **Dependencies:**
    *   Add `google_fonts` for typography.
    *   Add `provider` for state management to share the `Creature` and `Quest` data across the app.
3.  **State Management:**
    *   Create a `QuestProvider` to manage the list of quests (adding, completing, deleting).
    *   Create a `CreatureProvider` to manage the creature's state and XP.
4.  **Main Screen (`HomePage`):**
    *   **Creature Status View:** A prominent widget at the top of the screen displaying the creature's name, level, and an animated XP progress bar.
    *   **Quest List View:** A scrollable list of `Quest` items, each displayed as an interactive card with a title, XP value, and a checkbox.
    .
5.  **User Interaction:**
    *   Tapping the checkbox on a quest card will mark it as complete, trigger an animation, and update the creature's XP.
    *   If completing a quest causes the creature to level up, a celebratory animation or dialog will be shown.

This plan establishes a solid foundation for a fun and motivating application. Next, I will proceed with implementing the first steps.
