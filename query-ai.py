#!/usr/bin/env python
#
# Query the OpenAI API with the specified prompt and output # the response
#
# Copyright 2024 Diomidis Spinellis
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

import argparse
from openai import OpenAI
import io
import os
import sys

def query_openai(prompt, model, max_tokens):
    """
    Query OpenAI with a specified prompt using the ChatCompletion API.

    :param prompt: The text prompt to send to OpenAI.
    :param model: The model to use for the query (e.g., gpt-3.5-turbo).
    :param max_tokens: The maximum number of tokens to include in the response.
    :return: The response text from OpenAI.
    """
    # print(model,prompt)
    client = OpenAI()
    chat_completion = client.chat.completions.create(
        messages=[
            {
                "role": "user",
                "content": prompt,
            }
        ],
        model=model,
    )
    return chat_completion.choices[0].message.content.strip()

if __name__ == "__main__":
    # Set up argument parsing
    parser = argparse.ArgumentParser(description="Query OpenAI with a specified prompt.")
    parser.add_argument(
        "--model",
        type=str,
        default="gpt-4o",
        help="The OpenAI model to use (default: gpt-3.5-turbo)."
    )
    parser.add_argument(
        "--max_tokens",
        type=int,
        default=150,
        help="The maximum number of tokens to include in the response (default: 150)."
    )
    # Ensure stdin and stdout use UTF-8
    sys.stdin = io.TextIOWrapper(sys.stdin.buffer, encoding='utf-8')
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

    args = parser.parse_args()
    user_prompt = sys.stdin.read().strip()
    response = query_openai(user_prompt, args.model, args.max_tokens)
    print(response)
