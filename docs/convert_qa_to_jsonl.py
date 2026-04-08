#!/usr/bin/env python3
"""
Convert CHATBOT_TRAINING_QA.md into a JSONL fine-tuning dataset.

Usage:
    python3 docs/convert_qa_to_jsonl.py

Output:
    docs/training_data.jsonl   — ready for OpenAI / Hugging Face fine-tuning
    docs/training_data_rag.jsonl — chunked format for RAG embedding

The script reads the system prompt from CHATBOT_SYSTEM_PROMPT.md automatically.
"""

import json
import re
import os
import sys

DOCS_DIR = os.path.dirname(os.path.abspath(__file__))
QA_FILE = os.path.join(DOCS_DIR, "CHATBOT_TRAINING_QA.md")
SYSTEM_FILE = os.path.join(DOCS_DIR, "CHATBOT_SYSTEM_PROMPT.md")
OUT_JSONL = os.path.join(DOCS_DIR, "training_data.jsonl")
OUT_RAG = os.path.join(DOCS_DIR, "training_data_rag.jsonl")


def load_system_prompt(path):
    """Extract the system prompt text from between the triple-backtick block."""
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    # Find the block between the first ```\n and last ```
    match = re.search(r"```\n(You are FabricBot.*?)```", content, re.DOTALL)
    if match:
        return match.group(1).strip()
    # Fallback: return entire file content
    return content.strip()


def parse_qa_pairs(path):
    """Parse Q/A pairs from the markdown file.

    Format expected:
        **Q: <question>**

        A: <answer (possibly multi-paragraph)>
    """
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()

    pairs = []
    # Split on bold Q: markers
    # Pattern: **Q: ...** followed by A: block
    blocks = re.split(r"\n---\n", content)

    for block in blocks:
        # Find all Q/A pairs in this block
        qa_matches = re.findall(
            r"\*\*Q:\s*(.*?)\*\*\s*\n\s*A:\s*(.*?)(?=\n\*\*Q:|\Z)",
            block,
            re.DOTALL,
        )
        for q, a in qa_matches:
            question = q.strip()
            answer = a.strip()
            if question and answer:
                pairs.append({"question": question, "answer": answer})

    return pairs


def write_fine_tuning_jsonl(pairs, system_prompt, out_path):
    """Write OpenAI-format fine-tuning JSONL."""
    count = 0
    with open(out_path, "w", encoding="utf-8") as f:
        for pair in pairs:
            record = {
                "messages": [
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": pair["question"]},
                    {"role": "assistant", "content": pair["answer"]},
                ]
            }
            f.write(json.dumps(record, ensure_ascii=False) + "\n")
            count += 1
    return count


def write_rag_jsonl(pairs, out_path):
    """Write RAG-format JSONL (text chunks with metadata)."""
    count = 0
    with open(out_path, "w", encoding="utf-8") as f:
        for i, pair in enumerate(pairs):
            # Combine Q+A into one searchable chunk
            chunk = f"Q: {pair['question']}\n\nA: {pair['answer']}"
            record = {
                "id": f"qa_{i:04d}",
                "text": chunk,
                "metadata": {
                    "source": "CHATBOT_TRAINING_QA.md",
                    "type": "qa_pair",
                    "question": pair["question"][:120],
                },
            }
            f.write(json.dumps(record, ensure_ascii=False) + "\n")
            count += 1
    return count


def main():
    print("Loading system prompt...")
    system_prompt = load_system_prompt(SYSTEM_FILE)
    print(f"  System prompt: {len(system_prompt)} characters")

    print("Parsing Q&A pairs...")
    pairs = parse_qa_pairs(QA_FILE)
    print(f"  Found {len(pairs)} Q&A pairs")

    if not pairs:
        print("ERROR: No Q&A pairs found. Check the markdown format.", file=sys.stderr)
        sys.exit(1)

    print(f"Writing fine-tuning JSONL to {OUT_JSONL}...")
    count = write_fine_tuning_jsonl(pairs, system_prompt, OUT_JSONL)
    print(f"  Written {count} training examples")

    print(f"Writing RAG JSONL to {OUT_RAG}...")
    count = write_rag_jsonl(pairs, OUT_RAG)
    print(f"  Written {count} RAG chunks")

    print("\nDone!")
    print(f"  Fine-tuning dataset : {OUT_JSONL}")
    print(f"  RAG dataset         : {OUT_RAG}")
    print()
    print("Next steps:")
    print("  Fine-tuning: openai api fine_tuning.jobs.create -t training_data.jsonl -m gpt-4o-mini")
    print("  RAG        : embed training_data_rag.jsonl and load into your vector store")


if __name__ == "__main__":
    main()
