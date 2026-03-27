import os
from google.adk.models.lite_llm import LiteLlm
from opensage.agents.opensage_agent import OpenSageAgent


def mk_agent(opensage_session_id: str):
    return OpenSageAgent(
        name="my_ollama_agent",
        model=LiteLlm(
            model="ollama/qwen2.5:0.5b",
            api_base="http://localhost:11434",
        ),
        description="A simple agent using local Ollama model.",
        instruction="You are a helpful coding assistant.",
        tools=[],
    )
