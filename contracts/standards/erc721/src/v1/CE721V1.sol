//SPDX-License-Identifier:MIT

/**
 * @title CustomizedERC721
 * @author github.com/codermaybe
 * @dev CustomizedERC20 is a customized ERC20 token with a few additional features.
 * @dev 本合约仅用于学习和研究。所有复现均按照eip721标准。详见：https://github.com/ethereum/ERCs/blob/master/ERCS/erc-721.md
 * @dev 自行复现的erc721各项功能。interface文件夹中的所有文件为官方文档移植
 * @dev 逐行按照官方文档翻译方法的实现需求，请允许我偷点小懒用翻译 *。*
 * @dev V1版本特性：自定义_baseURI，_nextToken，以及mint、burn等方法，丰富构造器和管理功能
 */
import {ERC721} from "../interface/ERC721.sol";
import {ERC721TokenReceiver} from "../interface/ERC721TokenReceiver.sol";

pragma solidity ^0.8.28;

contract CE721V1 is ERC721 {
    ///@dev 以下截止到balanceOf函数的实现之前均为特性部分，官方文档无设定----------------------------
    ///@dev _balanceOf 记录对应地址的余额
    ///@dev _ownerOf 记录对应token的拥有者
    ///@dev  _approvedOf 记录代币单一授权列表
    ///@dev  _ApprovalForAll 记录某个地址授权的操作员列表

    mapping(address => uint) _balanceOf;

    mapping(uint256 => address) _ownerOf;

    mapping(uint256 => address) _approvedOf;

    mapping(address => mapping(address => bool)) _ApprovalForAll;

    ///@dev _contractOwner 记录此合约的拥有者
    ///@dev _projectName 记录此NFT项目的名称
    ///@dev _baseURI 记录NFT对应的链接地址
    ///@dev _nextToken 记录将派发的NFT编号

    address public _contractOwner;
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    string public _projectName;
    event ProjectNameChanged(string oldName, string newName);

    string public _baseURI;
    event BaseUriChanged(string _oldURI, string _newURI);

    uint256 public _nextToken;

    //初始构造函数，不附带任何数据
    constructor(string memory projectName, string memory baseURI) {
        _contractOwner = msg.sender;
        _projectName = projectName;
        _baseURI = baseURI;
        _nextToken = 0;
    }

    ///@notice 此处V1版本设定为有序token,注意initialOwners与initialTokenNumber的对应顺序。
    ///@notice 被抛弃的版本 constructor(string projectName,string baseURI,uint256[] initialTokenNumber ,address[] initialOwners,uint256 maximumTokenId)  此版本需对initialTokenNumber做重复鉴定,存在大量消耗gas费的问题
    ///@notice 0.8版本solidity不支持重载构造器，此处使用此函数实现
    ///@dev 此函数仅能被合约拥有者调用，且initialOwners长度必须与initialTokenNumber长度一致

    function initializeWithTokens(
        uint256 firstTokenNumber,
        uint256 lastTokenNumber,
        address[] memory initialOwners
    ) public {
        require(
            _contractOwner == msg.sender,
            "only contract owner can initialize"
        );
        require(
            firstTokenNumber <= lastTokenNumber,
            unicode"初始化数据失败,检查TokenNumber范围"
        );
        require(
            initialOwners.length == (lastTokenNumber - firstTokenNumber + 1),
            unicode"初始化数据参数数量不匹配"
        );
        //节省gas费所进行的操作，直接针对数据进行修改
        for (uint256 i = 0; i < initialOwners.length; i++) {
            require(initialOwners[i] != address(0), unicode"不能铸造给零地址");
            uint256 tokenId = firstTokenNumber + i;
            _mint(initialOwners[i], tokenId);
        }
        _nextToken = lastTokenNumber + 1;
    }

    function mint(address _to, uint256 _tokenId) public {
        require(msg.sender == _contractOwner, unicode"非合约管理员无法派发NFT");
        require(_ownerOf[_tokenId] == address(0), unicode"该NFT已存在");

        _mint(_to, _tokenId);

        // 更新_nextToken
        if (_tokenId >= _nextToken) {
            _nextToken = _tokenId + 1;
        }
    }

    function _mint(address to, uint256 tokenId) internal {
        require(to != address(0), unicode"不能铸造给零地址");
        require(_ownerOf[tokenId] == address(0), unicode"代币已存在");

        _balanceOf[to] += 1;
        _ownerOf[tokenId] = to;

        emit Transfer(address(0), to, tokenId);
    }

    function burn(uint256 _tokenId) public {
        require(
            msg.sender == _ownerOf[_tokenId] || msg.sender == _contractOwner,
            unicode"无权销毁"
        );
        _burn(_tokenId);
    }

    function _burn(uint256 tokenId) internal {
        address owner = _ownerOf[tokenId];

        // 清除授权
        _approvedOf[tokenId] = address(0);

        _balanceOf[owner] -= 1;
        _ownerOf[tokenId] = address(0);

        emit Transfer(owner, address(0), tokenId);
    }

    function transferOwnership(address newOwner) public {
        require(msg.sender == _contractOwner, unicode"只有所有者可以转移");
        require(newOwner != address(0), unicode"不可转给零地址");
        emit OwnerChanged(_contractOwner, newOwner);
        _contractOwner = newOwner;
    }

    ///个人设计部分结束

    /// @notice 计算分配给所有者的所有 NFT 数量。
    /// @dev 分配给零地址的 NFT 被视为无效，并且查询零地址会抛出异常。
    /// @param _owner 要查询余额的地址。
    /// @return `_owner` 拥有的 NFT 数量，可能为零。
    function balanceOf(address _owner) external view returns (uint256) {
        require(_owner != address(0), unicode"不可查询零地址");
        return _balanceOf[_owner];
    }

    /// @notice 查找 NFT 的所有者。
    /// @dev 分配给零地址的 NFT 被视为无效，并且查询它们会抛出异常。
    /// @param _tokenId NFT 的标识符。
    /// @return NFT 所有者的地址。
    function ownerOf(uint256 _tokenId) external view returns (address) {
        require(_ownerOf[_tokenId] != address(0), unicode"无效NFT,无所有者");
        return _ownerOf[_tokenId];
    }

    ///@dev 个人：初版data暂时忽略（不使用）
    /// 翻译
    /// @notice 将 NFT 的所有权从一个地址转移到另一个地址。
    /// @dev 除非 `msg.sender` 是当前所有者、授权的操作员或该 NFT 的批准地址，否则抛出异常。
    ///  如果 `_from` 不是当前所有者，则抛出异常。
    ///  如果 `_to` 是零地址，则抛出异常。
    ///  如果 `_tokenId` 不是有效的 NFT，则抛出异常。
    ///  当转移完成时，此函数会检查 `_to` 是否是智能合约（代码大小 > 0）。
    ///  如果是，它会在 `_to` 上调用 `onERC721Received`，如果返回值不是
    ///  `bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"))`，则抛出异常。
    /// @param _from NFT 的当前所有者。
    /// @param _to 新的所有者。
    /// @param _tokenId 要转移的 NFT。
    /// @param data 发送到 `_to` 的调用中的附加数据，没有指定的格式。
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId,
        bytes memory data
    ) external payable {
        require(
            msg.sender == _ownerOf[_tokenId] ||
                msg.sender == _approvedOf[_tokenId] ||
                _ApprovalForAll[_from][msg.sender],
            unicode"无操作权限,请检查"
        );
        require(_from == _ownerOf[_tokenId], unicode"from对象非此NFT拥有者");
        require(_to != address(0), unicode"安全转账不可对零地址");
        require(_ownerOf[_tokenId] != address(0), unicode"不是有效的NFT");
        if (address(_to).code.length > 0) {
            //按ERC721要求在_to上调用接口对应的 onERC721Received函数
            bytes4 retval = ERC721TokenReceiver(_to).onERC721Received(
                msg.sender,
                _from,
                _tokenId,
                data
            );
            require(
                retval ==
                    bytes4(
                        keccak256(
                            "onERC721Received(address,address,uint256,bytes)"
                        )
                    ),
                unicode"此合约地址未实现ERC721TokenReceiver"
            );
        }
        if (
            data.length == 4 &&
            bytes4(data) == bytes4(keccak256("codermaybe.github.io"))
        ) {
            //do something
        }
        //变更拥有者
        _ownerOf[_tokenId] = _to;
        _balanceOf[_to] += 1;
        _balanceOf[_from] -= 1;
        _approvedOf[_tokenId] = address(0);
        emit Transfer(_from, _to, _tokenId);
    }

    ///@dev 个人:屏蔽data的版本
    /// @notice 将 NFT 的所有权从一个地址转移到另一个地址。
    /// @dev 此函数与带有额外数据参数的另一个函数的工作方式相同，只是此函数将数据设置为 ""。
    /// @param _from NFT 的当前所有者。
    /// @param _to 新的所有者。
    /// @param _tokenId 要转移的 NFT。
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external payable {
        this.safeTransferFrom(_from, _to, _tokenId, "");
    }

    /// @notice 转移 NFT 的所有权 -- 调用者有责任
    ///  确认 `_to` 是否能够接收 NFT，否则它们可能会永久丢失。
    /// @dev 除非 `msg.sender` 是当前所有者、授权的操作员或该 NFT 的批准地址，否则抛出异常。
    ///  如果 `_from` 不是当前所有者，则抛出异常。
    ///  如果 `_to` 是零地址，则抛出异常。
    ///  如果 `_tokenId` 不是有效的 NFT，则抛出异常。
    /// @param _from NFT 的当前所有者。
    /// @param _to 新的所有者。
    /// @param _tokenId 要转移的 NFT。
    function transferFrom(
        address _from,
        address _to,
        uint256 _tokenId
    ) external payable {
        //判断是否能接收nft
        require(
            msg.sender == _ownerOf[_tokenId] ||
                msg.sender == _approvedOf[_tokenId] ||
                _ApprovalForAll[_from][msg.sender],
            unicode"无操作权限,请检查"
        );
        require(_from == _ownerOf[_tokenId], unicode"from对象非此NFT拥有者");
        require(_to != address(0), unicode"安全转账不可对零地址");
        require(_ownerOf[_tokenId] != address(0), unicode"不是有效的NFT");
        //变更拥有者,此处相对于safeTransfer少了对于_to是否是合约以及能否接收的判断，节省gas费，但存在一定风险
        _ownerOf[_tokenId] = _to;
        _balanceOf[_to] += 1;
        _balanceOf[_from] -= 1;
        //清空approved
        _approvedOf[_tokenId] = address(0);
        emit Transfer(_from, _to, _tokenId);
    }

    /// @notice 更改或确认 NFT 的批准地址。
    /// @dev 零地址表示没有批准地址。
    ///  除非 `msg.sender` 是当前 NFT 所有者或当前所有者的授权操作员，否则抛出异常。
    /// @param _approved 新的批准的 NFT 控制器。
    /// @param _tokenId 要批准的 NFT。
    function approve(address _approved, uint256 _tokenId) external payable {
        require(
            msg.sender == _ownerOf[_tokenId] ||
                _ApprovalForAll[_ownerOf[_tokenId]][msg.sender],
            unicode"无权限操作NFT批准"
        );
        _approvedOf[_tokenId] = _approved;
        emit Approval(_ownerOf[_tokenId], _approved, _tokenId);
    }

    ///@dev 个人：此处授权仅限NFT拥有者调用授权自身的批准，可以改进。
    /// @notice 启用或禁用第三方（“操作员”）管理 `msg.sender` 所有资产的批准。
    /// @dev 触发 ApprovalForAll 事件。合约必须允许每个所有者有多个操作员。
    /// @param _operator 要添加到授权操作员集合的地址。
    /// @param _approved 如果操作员被批准，则为 true；如果撤销批准，则为 false。
    function setApprovalForAll(address _operator, bool _approved) external {
        _ApprovalForAll[msg.sender][_operator] = _approved;
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    /// @notice 获取单个 NFT 的批准地址。
    /// @dev 如果 `_tokenId` 不是有效的 NFT，则抛出异常。
    /// @param _tokenId 要查找批准地址的 NFT。
    /// @return 此 NFT 的批准地址，如果没有，则为零地址。
    function getApproved(uint256 _tokenId) external view returns (address) {
        require(_ownerOf[_tokenId] != address(0), unicode"不是有效的NFT");
        return _approvedOf[_tokenId];
    }

    /// @notice 查询地址是否是另一个地址的授权操作员。
    /// @param _owner 拥有 NFT 的地址。
    /// @param _operator 代表所有者执行操作的地址。
    /// @return 如果 `_operator` 是 `_owner` 的批准操作员，则为 true；否则为 false。
    function isApprovedForAll(
        address _owner,
        address _operator
    ) external view returns (bool) {
        return _ApprovalForAll[_owner][_operator];
    }
}
