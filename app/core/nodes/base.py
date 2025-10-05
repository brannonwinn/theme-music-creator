from abc import ABC, abstractmethod
from typing import Type, Optional

from pydantic import BaseModel

from core.task import TaskContext

"""
Base Node Module

This module defines the foundational Node class that all workflow nodes inherit from.
It implements the Chain of Responsibility pattern, allowing nodes to process tasks
sequentially and pass results to the next node in the chain.
"""


class Node(ABC):
    class OutputType(BaseModel):
        pass

    def __init__(self, task_context: TaskContext = None):
        self.task_context = task_context

    def set_output(self, output: BaseModel):
        self.task_context.nodes[self.node_name] = output

    def get_output(self, node_class: Type["Node"]) -> Optional[OutputType]:
        return self.task_context.nodes.get(node_class.__name__, None)

    @property
    def node_name(self) -> str:
        """Gets the name of the node.

        Returns:
            String name derived from the class name
        """
        return self.__class__.__name__

    @abstractmethod
    async def process(self, task_context: TaskContext) -> TaskContext:
        """Processes the task context in the responsibility chain.

        This method implements the Chain of Responsibility pattern's handle
        method. Each node in the workflow processes the task and passes it
        to the next node through the workflow orchestrator.

        Args:
            task_context: The shared context object passed through the workflow

        Returns:
            Updated TaskContext with this node's processing results

        Note:
            Implementations should:
            1. Process the task according to their specific responsibility
            2. Store results in task_context.nodes[self.node_name]
        """
        pass
