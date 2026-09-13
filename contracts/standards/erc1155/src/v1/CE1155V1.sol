//SPDX-License-Identifier: MIT
/**
 * @title CustomizedERC1155
 * @author github.com/codermaybe
 * @dev CustomizedERC1155 is a customized ERC1155 implementation with a few additional features.
 * @dev 本合约仅用于学习和研究。所有复现均按照eip1155标准。详见：https://github.com/ethereum/ERCs/blob/master/ERCS/erc-1155.md
 * @dev 自行复现的erc1155各项功能。interface文件夹中的所有文件为官方文档移植
 * @dev 逐行按照官方文档翻译方法的实现需求，请允许我偷点小懒用翻译 *。*
 * @dev ERC1155标准相对复杂许多，生产建议直接使用OpenZeppelin。
 * @dev V1版本特性：data字段暂不具有任何特性，仅作为预留。
 */

pragma solidity ^0.8.28;

import {ERC1155} from "contracts/interfaces/erc1155/ERC1155.sol";
import {ERC1155TokenReceiver} from "contracts/interfaces/erc1155/ERC1155TokenReceiver.sol";

contract CE1155V1 is ERC1155 {
    //----------------------------------------个人实现部分起始--------------------------------------------------------

    ///@dev 此处起始直到safeTransferFrom函数起始，均为个人设计实现。
    ///@dev 此处以 元宇宙代表电影<头号玩家> 为例，实现一个简单的元宇宙物品仓库。首先设定此游戏名称为 "THE OASIS"!
    ///@dev 在此仓库中，用户可以存储和转移各种元宇宙物品，每个物品类目都有一个唯一的_id和名称，以及一个URI，用于标识该物品的图片。普通物品更需要一个余额，用于记录该物品的数量。
    /// @dev 当然，也有一些特殊的物品(NFT)，比如：通关的三把钥匙，我们命名为 red_key,blue_key,green_key ,以及唯一的通关钥匙，我们命名为 final_key。
    /// 别忘了还有让主角复活的唯一币 extra_life_coin
    //----------------管理者相关----------------
    address public manager;
    string public name = "THE OASIS";
    string public symbol = "OASIS";

    ///@dev 仅管理员可调用
    function setManager(address _manager) external {
        require(msg.sender == manager, unicode"仅管理员可操作");
        require(_manager != address(0), unicode"不可设置零地址");
        manager = _manager;
    }

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        manager = msg.sender;
    }

    //@param ItemInfo 记录每个物品的信息，此处暂为URI/名称/ID
    struct ItemInfo {
        string ItemName; //记录物品名称 例:goldcoin
        string ItemURI; //对应物品图片 例:https://tse3-mm.cn.bing.net/th/id/OIP-C.uX7OKK333q81S6ABKF6KdAHaEK?rs=1&pid=ImgDetMain
        uint256 ItemUniqueID; //记录物品在仓库中的唯一ID 例:1001
        bool IsNFT; //记录是否为NFT 给extra_life_coin等物品的特殊处理
        uint256 balance; //对于NFT,余额字段作用只能表示是否生成了此NFT。需要额外注意NFT的余额转账操作
    }

    struct ItemApproval {
        //记录对于某个物品的授权数量
        bool approved;
        uint256 approvedAmount;
    }

    mapping(uint256 => ItemInfo) public itemlist; //记录道具ID对应的信息

    mapping(uint256 => address) private _nftOwnerOf; //记录NFT对应持有者地址，可以先生成nft，后面再派发给拥有者(未派发的nft均为零地址，好区分是否被分配)

    mapping(address => mapping(uint256 => ItemInfo)) public _balanceOf; //记录用户地址对应的道具ID和余额;

    mapping(address => mapping(address => mapping(uint256 => ItemApproval)))
        private _singleApproval; //记录对于某个操作员的单一授权数量

    mapping(address => mapping(address => bool)) private _ApprovalForAll; //完全的账户授权

    /**
     * 踩坑记录1：所有的代码实现均为被动调用数据
     * 用户自己的道具列表无法主动检查
     * 方法1(V1版本中暂不实现)：
     * 设定基础的itemid为顺序值，每次添加新道具时，itemid+1，这样用户可以通过itemid来检查自己的道具列表。
     * 方法2(V1版本中暂不实现)：
     * 存放bytes类型变量(或其他)，按照bit位表达不同的道具，例bytes4，有32位表达，这样用户可以通过bytes4类型字节码来检查自己的道具列表。需满足方法1
     * 问题：游戏内道具增加时，需要不断扩大uint256类型字节码，这样会导致用户的道具列表无法准确表达。
     * 方法3(V1版本中暂不实现):
     * 方法2存在资产在链上数据庞大的问题,建议采用链下存储。，游戏公司可以根据address => itemid ->itemlist等方式记录用户数据表。
     * 建议备选方案为添加重新检索功能，当游戏公司数据不被信任时能根据链上数据恢复
     * 踩坑记录2：费用优化(仅记录设想)
     * 1.采用keccak256单独计算 道具name 生成id。所有string类型变量均存在无法控制大小和消耗的问题,并且能检验道具命名重复的问题
     * 此方法生成的id值消耗固定，但对于小规模游戏，无需存储大量数据，仍可能消耗过大。可以持续优化
     * 2.存储模式设计优化 ：链上数据结构优化。单独区分nft列表和普通道具列表。减少大量普通道具struct 内的 isNFT 字段
     */

    //简单读取字段列表，返回NFT判定关键字
    function isNFT(uint256 _id) public view returns (bool) {
        require(itemlist[_id].ItemUniqueID != 0, unicode"该道具不存在");
        return itemlist[_id].IsNFT;
    }

    ///新增道具功能，仅管理员可调用
    ///@param _name 道具名称
    /// @param _URI 道具图片URI
    /// @param _id 道具ID
    /// @param _isNFT 道具是否为NFT
    function addItem(
        string memory _name,
        string memory _URI,
        uint256 _id,
        bool _isNFT
    ) external {
        require(msg.sender == manager, unicode"仅管理员可操作");
        require(itemlist[_id].ItemUniqueID == 0, unicode"该道具已存在");
        itemlist[_id].ItemName = _name;
        itemlist[_id].ItemURI = _URI;
        itemlist[_id].ItemUniqueID = _id;
        itemlist[_id].IsNFT = _isNFT;
    }

    ///@dev 仅管理员可调用
    function mint(address _to, uint256 _id, uint256 _value) external {
        //本可以调用safetransfer，但需要一点特殊处理，此处不做调用
        require(msg.sender == manager, unicode"仅管理员可操作");
        require(itemlist[_id].ItemUniqueID != 0, unicode"该道具不存在");
        require(_to != address(0), unicode"不可转账至零地址");
        if (itemlist[_id].IsNFT) {
            require(_value == 1, unicode"NFT道具只能生成一个");
            require(
                _nftOwnerOf[_id] == address(0),
                unicode"此NFT已被分配给用户"
            );
            _nftOwnerOf[_id] = _to;
        }
        _balanceOf[_to][_id].balance = _value;
        emit TransferSingle(msg.sender, address(0), _to, _id, _value);
    }

    //燃烧道具，仅管理员可调用
    function burn(address _from, uint256 _id, uint256 _value) external {
        require(msg.sender == manager, unicode"仅管理员可操作");
        require(itemlist[_id].ItemUniqueID != 0, unicode"该道具不存在");
        require(
            msg.sender == _from ||
                _ApprovalForAll[_from][msg.sender] ||
                _singleApproval[_from][msg.sender][_id].approved,
            unicode"无操作权限销毁道具"
        );
        require(_from != address(0), unicode"调用目标地址不合法");
        if (_singleApproval[_from][msg.sender][_id].approved) {
            require(
                _singleApproval[_from][msg.sender][_id].approvedAmount >=
                    _value,
                unicode"授权数量不足"
            );
            _singleApproval[_from][msg.sender][_id].approvedAmount -= _value;
            _balanceOf[_from][_id].balance -= _value;
            if (isNFT(_id)) {
                _nftOwnerOf[_id] = address(0);
            } //此设计中无法销毁NFT，只能将其NFT 持有者地址设置为零地址。如果需要完全无法调用，需要在NFT字段添加关键字（V1版本中暂不支持）。
        } else {
            require(
                _balanceOf[_from][_id].balance >= _value,
                unicode"账户余额不足"
            );
            _balanceOf[_from][_id].balance -= _value;
            if (isNFT(_id)) {
                _nftOwnerOf[_id] = address(0);
            }
        }

        emit TransferSingle(msg.sender, _from, address(0), _id, _value);
    }

    ///@dev 设置账户单物品权限
    ///@dev 不做账户余额、授权数量合理性检验，在转账逻辑中判断是否合理
    function setApprovalForSingle(
        address _approved,
        uint256 _id,
        uint256 _value
    ) external {
        require(_approved != address(0), unicode"不可授权至零地址");
        require(
            _balanceOf[msg.sender][_id].ItemUniqueID != 0,
            unicode"该道具不存在"
        );
        require(
            _balanceOf[msg.sender][_id].balance >= _value,
            unicode"余额不足"
        );
        _singleApproval[msg.sender][_approved][_id].approved = true;
        _singleApproval[msg.sender][_approved][_id].approvedAmount = _value;
    }

    //----------------------------------------个人实现部分结束--------------------------------------------------------
    /**
        @notice 将 `_value` 数量的 `_id` 从 `_from` 地址转移到指定的 `_to` 地址（带有安全调用）。
        @dev 调用者必须被批准管理从 `_from` 帐户转移出的代币（参见标准的“批准”部分）。
        如果 `_to` 是零地址，则必须回退。
        如果代币 `_id` 的持有者余额低于发送的 `_value`，则必须回退。
        在任何其他错误情况下，都必须回退。
        必须发出 `TransferSingle` 事件以反映余额变化（参见标准的“安全转移规则”部分）。
        在满足上述条件后，此函数必须检查 `_to` 是否为智能合约（例如，代码大小 > 0）。如果是，则必须在 `_to` 上调用 `onERC1155Received` 并采取适当的操作（参见标准的“安全转移规则”部分）。
        @param _from     源地址
        @param _to       目标地址
        @param _id       代币类型的 ID
        @param _value    转移数量
        @param _data     附加数据，没有指定格式，必须在对 `_to` 的 `onERC1155Received` 调用中保持不变
    */
    //Safe Transfer Rules :https://github.com/ethereum/ERCs/blob/master/ERCS/erc-1155.md#safe-transfer-rules
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        uint256 _value,
        bytes calldata _data
    ) external {
        require(
            msg.sender == _from ||
                _singleApproval[_from][msg.sender][_id].approved ||
                _ApprovalForAll[_from][msg.sender],
            unicode"无权进行此转账，未经授权或不是本人"
        );
        require(_to != address(0), unicode"不可转账至零地址");
        require(
            _balanceOf[_from][_id].balance >= _value,
            unicode"账户余额不足"
        );
        if (_singleApproval[_from][msg.sender][_id].approved) {
            //单独判断是否为单一授权，拥有者和操作员可以对余额进行完全调用，所以无需判断
            require(
                _singleApproval[_from][msg.sender][_id].approvedAmount >=
                    _value,
                unicode"授权数量不足"
            );
            _singleApproval[_from][msg.sender][_id].approvedAmount -= _value;
        }
        _balanceOf[_from][_id].balance -= _value; //在调用接收者合约上的 ERC1155TokenReceiver hook之前，转账的余额必须已被更新   Scenario#6
        emit TransferSingle(msg.sender, _from, _to, _id, _value); //在调用接收者合约上的 ERC1155TokenReceiver hook之前，必须已发出转账事件以反映余额变更。 Scenario#6
        //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!需修改部分！！！！！！！！！！！！！！！！
        if (_to.code.length > 0) {
            //onERC1155Received 或 onERC1155BatchReceived 必须在接收转账的合约上至少被调用一个
            bytes4 retval1 = ERC1155TokenReceiver(_to).onERC1155Received(
                msg.sender,
                _from,
                _id,
                _value,
                _data
            ); //onERC1155Received必须被调用，且必须得遵循规则
            require(
                retval1 ==
                    bytes4(
                        keccak256(
                            "onERC1155Received(address,address,uint256,uint256,bytes)"
                        )
                    ),
                unicode"此合约地址未实现ERC1155TokenReceiver"
            );
            //需补充部分，此处应为批量转账的判断，由于此合约中没有批量转账的函数，所以此处不做判断。
            //如果需要批量转账，需要在接收者合约上实现 onERC1155BatchReceived 函数，并在 safeBatchTransferFrom 函数中调用。
            /*
        bytes4 retval2 =  ERC1155TokenReceiver(_to).onERC1155BatchReceived(msg.sender,_from,_id,_value,_data);//可选  这个函数可能没有被调用，但是必须得遵循规则
        require(
            retval2 ==
                bytes4(
                    keccak256(
                        "onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"
                    )
                ),
            unicode"此合约地址未实现ERC1155TokenReceiver"
        );
        
        */
        }
    }

    /**
        @notice 将 `_values` 数量的 `_ids` 从 `_from` 地址转移到指定的 `_to` 地址（带有安全调用）。
        @dev 调用者必须被批准管理从 `_from` 帐户转移出的代币（参见标准的“批准”部分）。
        如果 `_to` 是零地址，则必须回退。
        如果 `_ids` 的长度与 `_values` 的长度不相同，则必须回退。
        如果 `_ids` 中代币持有者的任何余额低于发送给接收者的 `_values` 中的相应数量，则必须回退。
        在任何其他错误情况下，都必须回退。
        必须发出 `TransferSingle` 或 `TransferBatch` 事件，以便反映所有余额变化（参见标准的“安全转移规则”部分）。
        余额变化和事件必须遵循数组的顺序（`_ids[0]/_values[0]` 在 `_ids[1]/_values[1]` 之前，等等）。
        在满足批量转移的上述条件后，此函数必须检查 `_to` 是否为智能合约（例如，代码大小 > 0）。如果是，则必须在 `_to` 上调用相关的 `ERC1155TokenReceiver` 钩子并采取适当的操作（参见标准的“安全转移规则”部分）。
        @param _from     源地址
        @param _to       目标地址
        @param _ids      每个代币类型的 ID（顺序和长度必须与 `_values` 数组匹配）
        @param _values   每个代币类型的转移数量（顺序和长度必须与 `_ids` 数组匹配）
        @param _data     附加数据，没有指定格式，必须在对 `_to` 的 `ERC1155TokenReceiver` 钩子的调用中保持不变
    */

    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] calldata _ids,
        uint256[] calldata _values,
        bytes calldata _data
    ) external {
        require(
            msg.sender == _from ||
                _ApprovalForAll[_from][msg.sender] ||
                _singleApproval[_from][msg.sender][_ids[0]].approved, //此处singleApproval仅作首个物品授权人验证，区分不合理情况,下方进行批量判断
            unicode"无权进行此转账，未经完全授权或不是本人"
        );
        require(_to != address(0), unicode"不可转账至零地址");
        require(_ids.length == _values.length, unicode"参数长度不匹配");
        //针对两种不同权限情况进行条件检测，条件符合后进行批量转账(节省gas费。批量做条件判断符合后再进行批量操作)
        if (_singleApproval[_from][msg.sender][_ids[0]].approved) {
            for (uint256 i = 0; i < _ids.length; i++) {
                //检测
                require(
                    _singleApproval[_from][msg.sender][_ids[i]]
                        .approvedAmount >= _values[i],
                    unicode"授权数量不足"
                );
                require(
                    _balanceOf[_from][_ids[i]].balance >= _values[i],
                    unicode"账户某物品余额不足"
                );
            }
        } else {
            for (uint256 i = 0; i < _ids.length; i++) {
                require(
                    _balanceOf[_from][_ids[i]].balance >= _values[i],
                    unicode"账户某物品余额不足"
                );
            }
        }
        //批量转账
        if (_singleApproval[_from][msg.sender][_ids[0]].approved) {
            for (uint256 i = 0; i < _ids.length; i++) {
                _singleApproval[_from][msg.sender][_ids[i]]
                    .approvedAmount -= _values[i];
                _balanceOf[_from][_ids[i]].balance -= _values[i];
            }
        } else {
            for (uint256 i = 0; i < _ids.length; i++) {
                _balanceOf[_from][_ids[i]].balance -= _values[i];
            }
        }

        emit TransferBatch(msg.sender, _from, _to, _ids, _values); //在调用接收者合约上的 ERC1155TokenReceiver hook之前，必须已发出转账事件以反映余额变更。 Scenario#6
        //!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!需修改部分！！！！！！！！！！！！！！！！

        if (_to.code.length > 0) {
            //onERC1155Received 或 onERC1155BatchReceived 必须在接收转账的合约上至少被调用一个
            //bytes4 retval1 =  ERC1155TokenReceiver(_to).onERC1155Received(msg.sender,_from,_ids[0],_values[0],_data);//onERC1155Received必须被调用，且必须得遵循规则
            /*require(
            retval1 ==
                bytes4(
                    keccak256(
                        "onERC1155Received(address,address,uint256,uint256,bytes)"
                    )
                ),
            unicode"此合约地址未实现ERC1155TokenReceiver"
        );
        */
            bytes4 retval2 = ERC1155TokenReceiver(_to).onERC1155BatchReceived(
                msg.sender,
                _from,
                _ids,
                _values,
                _data
            ); //可选  这个函数可能没有被调用，但是必须得遵循规则

            //需修正或完善部分
            require(
                retval2 ==
                    bytes4(
                        keccak256(
                            "onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"
                        )
                    ),
                unicode"此合约地址未实现ERC1155TokenReceiver"
            );
        }
    }

    /**
        @notice 获取帐户代币的余额。
        @param _owner    代币持有者的地址
        @param _id       代币的 ID
        @return         请求的代币类型的 `_owner` 的余额
    */
    function balanceOf(
        address _owner,
        uint256 _id
    ) external view returns (uint256) {
        return _balanceOf[_owner][_id].balance;
    }

    /**
        @notice 获取多个帐户/代币对的余额
        @param _owners   代币持有者的地址
        @param _ids      代币的 ID
        @return         请求的代币类型的 `_owner` 的余额（即，每个 (owner, id) 对的余额）
    */
    function balanceOfBatch(
        address[] calldata _owners,
        uint256[] calldata _ids
    ) external view returns (uint256[] memory) {
        uint256[] memory result = new uint256[](_owners.length);
        for (uint256 i = 0; i < _owners.length; i++) {
            result[i] = _balanceOf[_owners[i]][_ids[i]].balance;
        }
        return result;
    }

    /**
        @notice 启用或禁用第三方（“操作员”）管理调用者所有代币的批准。
        @dev 成功时必须发出 `ApprovalForAll` 事件。
        @param _operator  添加到授权操作员集合的地址
        @param _approved  如果操作员被批准，则为 true；如果撤销批准，则为 false
    */
    function setApprovalForAll(address _operator, bool _approved) external {
        _ApprovalForAll[msg.sender][_operator] = _approved; //直接覆盖，不做增删
        emit ApprovalForAll(msg.sender, _operator, _approved);
    }

    /**
        @notice 查询给定所有者的操作员的批准状态。
        @param _owner     代币的所有者
        @param _operator  授权操作员的地址
        @return         如果操作员被批准，则为 true；如果未被批准，则为 false
    */
    function isApprovedForAll(
        address _owner,
        address _operator
    ) external view returns (bool) {
        return _ApprovalForAll[_owner][_operator];
    }
}
