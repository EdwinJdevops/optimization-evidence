from __future__ import annotations

from dataclasses import dataclass
from enum import StrEnum


class ExperimentState(StrEnum):
    OBSERVED = "OBSERVED"
    MODELED = "MODELED"
    APPROVED = "APPROVED"
    APPLIED = "APPLIED"
    OPERATIONALLY_VERIFIED = "OPERATIONALLY_VERIFIED"
    CAPACITY_REALIZED = "CAPACITY_REALIZED"
    BILL_OBSERVED = "BILL_OBSERVED"
    ATTRIBUTION_VERIFIED = "ATTRIBUTION_VERIFIED"
    REALIZED = "REALIZED"
    UNSAFE = "UNSAFE"
    ROLLED_BACK = "ROLLED_BACK"
    INCONCLUSIVE = "INCONCLUSIVE"
    NO_CASH_SAVING = "NO_CASH_SAVING"
    ATTRIBUTION_FAILED = "ATTRIBUTION_FAILED"


class InvalidTransition(ValueError):
    pass


_ALLOWED_TRANSITIONS: dict[ExperimentState, frozenset[ExperimentState]] = {
    ExperimentState.OBSERVED: frozenset({ExperimentState.MODELED, ExperimentState.INCONCLUSIVE}),
    ExperimentState.MODELED: frozenset({ExperimentState.APPROVED, ExperimentState.INCONCLUSIVE}),
    ExperimentState.APPROVED: frozenset({ExperimentState.APPLIED, ExperimentState.INCONCLUSIVE}),
    ExperimentState.APPLIED: frozenset(
        {
            ExperimentState.OPERATIONALLY_VERIFIED,
            ExperimentState.UNSAFE,
            ExperimentState.ROLLED_BACK,
            ExperimentState.INCONCLUSIVE,
        }
    ),
    ExperimentState.OPERATIONALLY_VERIFIED: frozenset(
        {
            ExperimentState.CAPACITY_REALIZED,
            ExperimentState.NO_CASH_SAVING,
            ExperimentState.INCONCLUSIVE,
        }
    ),
    ExperimentState.CAPACITY_REALIZED: frozenset(
        {ExperimentState.BILL_OBSERVED, ExperimentState.INCONCLUSIVE}
    ),
    ExperimentState.BILL_OBSERVED: frozenset(
        {
            ExperimentState.ATTRIBUTION_VERIFIED,
            ExperimentState.NO_CASH_SAVING,
            ExperimentState.ATTRIBUTION_FAILED,
            ExperimentState.INCONCLUSIVE,
        }
    ),
    ExperimentState.ATTRIBUTION_VERIFIED: frozenset(
        {
            ExperimentState.REALIZED,
            ExperimentState.NO_CASH_SAVING,
            ExperimentState.ATTRIBUTION_FAILED,
        }
    ),
    ExperimentState.UNSAFE: frozenset({ExperimentState.ROLLED_BACK}),
    ExperimentState.REALIZED: frozenset(),
    ExperimentState.ROLLED_BACK: frozenset(),
    ExperimentState.INCONCLUSIVE: frozenset(),
    ExperimentState.NO_CASH_SAVING: frozenset(),
    ExperimentState.ATTRIBUTION_FAILED: frozenset(),
}


@dataclass(slots=True)
class Experiment:
    experiment_id: str
    state: ExperimentState = ExperimentState.OBSERVED

    def transition_to(self, target: ExperimentState) -> None:
        allowed = _ALLOWED_TRANSITIONS[self.state]
        if target not in allowed:
            raise InvalidTransition(f"cannot transition {self.state} -> {target}")
        self.state = target

    def can_transition_to(self, target: ExperimentState) -> bool:
        return target in _ALLOWED_TRANSITIONS[self.state]
