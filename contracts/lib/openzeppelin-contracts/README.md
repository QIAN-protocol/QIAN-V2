

### Changes

+ ERC20.sol

```sol
    constructor (string memory name_, string memory symbol_) public {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }
```

```sol
    function _ERC20 (string memory name_, string memory symbol_) internal {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }
```


+ ReentrancyGuard.sol


```sol
    constructor () internal {
        _status = _NOT_ENTERED;
    }
```

```sol
    function _ReentrancyGuard() internal {
        _status = _NOT_ENTERED;
    }
```


