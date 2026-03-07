# Spec: Prompting Style and Practice Evolution Analysis

## Overview
A qualitative and quantitative analysis of how AI prompting practices have evolved in this repository over the last 3 months. The study focuses on the shift from conversational/imperative styles (Aider) to structured/spec-driven workflows (Conductor/Opencode).

## Functional Requirements
1. **Data Collection**:
    - **Source A (Local Logs)**: Extract early prompting patterns from `.aider.chat.history.md`.
    - **Source B (Git AI)**: Query the `git-ai` prompt database for recent, high-structured sessions.
    - **Source C (Commits)**: Analyze commit message structure and diff metadata from Nov 2025 vs. Feb 2026.
2. **Analysis Dimensions**:
    - **Clarity & Specificity**: Compare vague instructions vs. context-rich specifications.
    - **Tool Proficiency**: Evaluate the transition from ad-hoc chat to multi-agent orchestration.
    - **Error Correction**: Measure the reduction/increase in "fix-up" iterations.
    - **Code Acceptance**: Correlate prompt structure with code retention (using Git AI metrics).
3. **Synthesis**:
    - Produce a detailed Markdown report summarizing findings and "lessons learned".

## Acceptance Criteria
1. A report file exists in the track directory detailing the evolution.
2. Comparison includes specific examples of "Old Style" vs. "New Style".
3. Report includes metrics on iteration counts and acceptance rates (where available).
