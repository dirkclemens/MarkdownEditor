#!/bin/bash
set -e
cd "$(dirname "$0")/.."
mkdir -p .build
swiftc -o .build/tokenizer-tests MarkdownEditor/MarkdownTokenizer.swift Tests/main.swift
.build/tokenizer-tests
