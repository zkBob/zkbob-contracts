// SPDX-License-Identifier: CC0-1.0

pragma solidity 0.8.15;

import "./BaseMinter.sol";

/**
 * @title DebtMinter
 * BOB minting/burning middleware for generic debt-minting use-cases.
 */
contract DebtMinter is BaseMinter {
    struct Parameters {
        uint104 maxDebtLimit; // max possible debt limit
        uint104 minDebtLimit; // min possible debt limit
        uint48 raiseDelay; // min delay between raises of debt limit
        uint96 raise; // debt limit raising step
        address treasury; // receiver of excess re-payed debt
    }

    struct State {
        uint104 debtLimit; // current debt limit, minDebtLimit <= debtLimit <= maxDebtLimit
        uint104 debt; // current debt value
        uint48 lastRaise; // timestamp of last debt limit raise
    }

    Parameters internal parameters;
    State internal state;

    event UpdateDebt(uint104 debt, uint104 debtLimit);

    constructor(
        address _token,
        uint104 _maxDebtLimit,
        uint104 _minDebtLimit,
        uint48 _raiseDelay,
        uint96 _raise,
        address _treasury
    )
        BaseMinter(_token)
    {
        require(_minDebtLimit + uint104(_raise) <= _maxDebtLimit, "DebtMinter: invalid raise");
        parameters = Parameters(_maxDebtLimit, _minDebtLimit, _raiseDelay, _raise, _treasury);
        state = State(_minDebtLimit, 0, uint48(block.timestamp));
    }

    function getState() external view returns (State memory) {
        return state;
    }

    function getParameters() external view returns (Parameters memory) {
        return parameters;
    }

    function maxDebtIncrease() external view returns (uint256) {
        Parameters memory p = parameters;
        State memory s = state;
        _updateDebtLimit(p, s);
        return s.debtLimit - s.debt;
    }

    function updateParameters(Parameters calldata _params) external onlyOwner {
        require(_params.minDebtLimit + uint104(_params.raise) <= _params.maxDebtLimit, "DebtMinter: invalid raise");
        parameters = _params;

        State memory s = state;
        _updateDebtLimit(_params, s);
        state = s;

        emit UpdateDebt(s.debt, s.debtLimit);
    }

    /**
     * @dev Internal function for adjusting debt limits on tokens mint.
     * @param _amount amount of minted tokens.
     */
    function _beforeMint(uint256 _amount) internal override {
        Parameters memory p = parameters;
        State memory s = state;

        _updateDebtLimit(p, s);
        s.debt += uint104(_amount);
        require(s.debt <= s.debtLimit, "DebtMinter: exceeds debt limit");

        state = s;

        emit UpdateDebt(s.debt, s.debtLimit);
    }

    /**
     * @dev Internal function for adjusting debt limits on tokens burn.
     * @param _amount amount of burnt tokens.
     */
    function _beforeBurn(uint256 _amount) internal override {
        Parameters memory p = parameters;
        State memory s = state;

        unchecked {
            if (_amount <= s.debt) {
                s.debt -= uint104(_amount);
            } else {
                IMintableERC20(token).mint(p.treasury, _amount - s.debt);
                s.debt = 0;
            }
        }
        _updateDebtLimit(p, s);

        state = s;

        emit UpdateDebt(s.debt, s.debtLimit);
    }

    function _updateDebtLimit(Parameters memory p, State memory s) internal view {
        if (s.debt >= p.maxDebtLimit) {
            s.debtLimit = s.debt;
        } else {
            uint104 newDebtLimit = s.debt + p.raise;
            if (newDebtLimit < p.minDebtLimit) {
                s.debtLimit = p.minDebtLimit;
                return;
            }

            if (newDebtLimit > p.maxDebtLimit) {
                newDebtLimit = p.maxDebtLimit;
            }
            if (newDebtLimit <= s.debtLimit) {
                s.debtLimit = newDebtLimit;
            } else if (s.lastRaise + p.raiseDelay < block.timestamp) {
                s.debtLimit = newDebtLimit;
                s.lastRaise = uint48(block.timestamp);
            }
        }
    }
}
