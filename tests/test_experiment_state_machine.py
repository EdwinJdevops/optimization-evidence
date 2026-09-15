import pytest

from optimization_evidence import Experiment, ExperimentState, InvalidTransition


def advance_to_operationally_verified(experiment: Experiment) -> None:
    for state in (
        ExperimentState.MODELED,
        ExperimentState.APPROVED,
        ExperimentState.APPLIED,
        ExperimentState.OPERATIONALLY_VERIFIED,
    ):
        experiment.transition_to(state)


def test_happy_path_requires_capacity_billing_and_attribution() -> None:
    experiment = Experiment("EXP-001-B")
    advance_to_operationally_verified(experiment)
    for state in (
        ExperimentState.CAPACITY_REALIZED,
        ExperimentState.BILL_OBSERVED,
        ExperimentState.ATTRIBUTION_VERIFIED,
        ExperimentState.REALIZED,
    ):
        experiment.transition_to(state)
    assert experiment.state is ExperimentState.REALIZED


def test_operational_success_can_end_with_zero_cash_saving() -> None:
    experiment = Experiment("EXP-001-A")
    advance_to_operationally_verified(experiment)
    experiment.transition_to(ExperimentState.NO_CASH_SAVING)
    assert experiment.state is ExperimentState.NO_CASH_SAVING


def test_cannot_skip_from_operational_verification_to_realized() -> None:
    experiment = Experiment("EXP-001-B")
    advance_to_operationally_verified(experiment)
    with pytest.raises(InvalidTransition):
        experiment.transition_to(ExperimentState.REALIZED)


def test_unsafe_change_can_only_roll_back() -> None:
    experiment = Experiment("EXP-unsafe")
    for state in (ExperimentState.MODELED, ExperimentState.APPROVED, ExperimentState.APPLIED):
        experiment.transition_to(state)
    experiment.transition_to(ExperimentState.UNSAFE)
    assert experiment.can_transition_to(ExperimentState.ROLLED_BACK)
    assert not experiment.can_transition_to(ExperimentState.REALIZED)


def test_terminal_outcome_cannot_be_rewritten() -> None:
    experiment = Experiment("EXP-001-A")
    advance_to_operationally_verified(experiment)
    experiment.transition_to(ExperimentState.NO_CASH_SAVING)
    with pytest.raises(InvalidTransition):
        experiment.transition_to(ExperimentState.REALIZED)
