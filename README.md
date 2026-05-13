# Módulo SystemVerilog de Im2Col

## Visão Geral

O módulo `img2row` implementa a operação **Im2Col** (*image to column*) em hardware, transformando uma janela de imagem 2D em uma matriz de colunas usada tipicamente como pré-processamento para convolução via multiplicação de matrizes (GEMM). É parametrizável em largura de dados, tamanho do kernel, tamanho da janela de entrada e stride. A versão 2.0 introduz **paralelismo espacial de janelas**: múltiplos patches de linhas distintas são extraídos e gravados simultaneamente a cada ciclo de clock.

## Parâmetros

| Parâmetro      | Tipo       | Padrão | Descrição                                               |
|----------------|------------|--------|---------------------------------------------------------|
| `WIDTH`        | `integer`  | `4`    | Largura em bits de cada pixel                           |
| `SIZE_KER`     | `integer`  | `3`    | Dimensão do kernel (ex.: 3 para kernel 3×3)             |
| `SIZE_WINDOW`  | `integer`  | `6`    | Dimensão da janela de entrada (ex.: 6 para imagem 6×6)  |
| `STRIDE`       | `integer`  | `3`    | Passo de deslocamento entre patches consecutivos        |

### Parâmetros Locais (calculados automaticamente)

| Parâmetro local  | Fórmula                           | Descrição                                         |
|------------------|-----------------------------------|---------------------------------------------------|
| `OUT_SIZE`       | `SIZE_WINDOW - SIZE_KER + 1`      | Número de posições de patch por dimensão          |
| `OUT_SIZE_NORM`  | `$clog2(2^(OUT_SIZE × OUT_SIZE))` | Largura do índice para endereçar todos os patches |

## Interface de Sinais

| Sinal        | Direção | Largura                                                   | Descrição                                                    |
|--------------|---------|-----------------------------------------------------------|--------------------------------------------------------------|
| `clk`        | Entrada | 1                                                         | Clock do sistema                                             |
| `rst_n_sync` | Entrada | 1                                                         | Reset síncrono ativo em nível baixo                          |
| `valid_i`    | Entrada | 1                                                         | Indica que `img` contém dados válidos prontos para processar |
| `ready_o`    | Saída   | 1                                                         | Módulo pronto para receber nova imagem                       |
| `rvalid_o`   | Saída   | 1                                                         | Resultado disponível em `colout`                             |
| `rready_i`   | Entrada | 1                                                         | Consumidor pronto para aceitar o resultado                   |
| `img`        | Entrada | `[WIDTH-1:0][SIZE_WINDOW-1:0][SIZE_WINDOW-1:0]`           | Janela de imagem de entrada                                  |
| `colout`     | Saída   | `[WIDTH-1:0][OUT_SIZE_NORM-1:0][OUT_SIZE_NORM-1:0]`       | Matriz Im2Col resultante                                     |

O handshake de entrada segue o protocolo **valid/ready**, assim como o de saída (**rvalid/rready**), compatível com interfaces AXI-Stream.

## Funcionamento

### Paralelismo Espacial de Janelas (v2.0)

A principal novidade desta versão é a extração paralela de `OUT_SIZE - STRIDE + 1` patches por ciclo. Em cada iteração, o módulo processa simultaneamente todas as linhas espaçadas por `STRIDE`, mantendo a coluna `col` fixa. Os patches resultantes são gravados em posições consecutivas de `colout` separadas por `OUT_SIZE`.

A extração dos pixels é feita combinacionalmente via `generate`:

```systemverilog
// Para cada janela paralela k e cada pixel (i, j) do kernel:
window0[k][i*SIZE_KER + j] = img[i + k*STRIDE][j + col];
```

Os pixels de cada janela são então achatados para uma palavra de `WIDTH * SIZE_KER * SIZE_KER` bits:

```systemverilog
window_f0[k] = {>>{window0[k]}};
```

### Escrita na Saída

A cada ciclo de clock no estado `TRANSFORM_IMAGE2COL`, são gravados `OUT_SIZE - STRIDE + 1` patches em paralelo:

```systemverilog
for (int i = 0; i < OUT_SIZE - STRIDE + 1; i++)
    colout[patch_idx_next + i*OUT_SIZE] <= {zero_pad, window_f0[i]};
```

onde `patch_idx_next = col` representa o índice base de coluna do ciclo atual.

### Máquina de Estados (FSM)

O módulo possui três estados:

```
IDLE ──(valid_i=1)──► TRANSFORM_IMAGE2COL ──(is_col_oob=1)──► DONE ──(rready_i=1)──► IDLE
```

| Estado                  | Comportamento                                                                          |
|-------------------------|----------------------------------------------------------------------------------------|
| `IDLE`                  | Aguarda `valid_i`. `ready_o=1`, `rvalid_o=0`                                           |
| `TRANSFORM_IMAGE2COL`   | Varre as posições de coluna com stride, gravando patches em paralelo. `ready_o=0`, `rvalid_o=0` |
| `DONE`                  | Sinaliza resultado pronto com `rvalid_o=1`. Aguarda `rready_i` para voltar ao `IDLE`   |

### Lógica de Avanço de Posição

Na versão 2.0, `is_row_oob` é **sempre verdadeiro** (`assign is_row_oob = '1`), pois o avanço de linha é implícito no paralelismo espacial. O controle efetivo é feito apenas por `is_col_oob`:

```systemverilog
assign is_col_oob = (col > OUT_SIZE - 2);
```

| `is_row_oob` | `is_col_oob` | Ação                                     |
|:---:|:---:|------------------------------------------|
| 1   | 0   | Incrementa `col` em `STRIDE`             |
| 1   | 1   | Mantém posição (transição para `DONE`)   |

> **Nota:** Os casos `is_row_oob=0` da tabela FSM da v1.0 não ocorrem mais nesta versão, pois `is_row_oob` é fixado em `1`.

## Exemplo de Uso

```systemverilog
img2row #(
    .WIDTH      (8),
    .SIZE_KER   (3),
    .SIZE_WINDOW(6),
    .STRIDE     (3)
) u_img2row (
    .clk         (clk),
    .rst_n_sync  (rst_n),
    .valid_i     (data_valid),
    .ready_o     (module_ready),
    .rvalid_o    (result_valid),
    .rready_i    (downstream_ready),
    .img         (input_image),
    .colout      (col_matrix)
);
```

Com `SIZE_WINDOW=6`, `SIZE_KER=3` e `STRIDE=3`: `OUT_SIZE = 4`, e a cada ciclo são gravados `OUT_SIZE - STRIDE + 1 = 2` patches em paralelo.

## Limitações e Observações

- O módulo processa **uma janela por vez**; uma nova imagem só pode ser enviada após o consumidor aceitar o resultado (`rready_i=1`).
- `patch_idx` é registrado com um ciclo de atraso em relação a `patch_idx_next` (que equivale a `col`); confirme o alinhamento temporal ao integrar com outros módulos.
- `is_row_oob` está fixado em `'1` — o controle por linha foi eliminado; a varredura ocorre exclusivamente na dimensão de coluna com passo `STRIDE`.
- O módulo foi projetado e testado com `WIDTH=4`, `SIZE_KER=3`, `SIZE_WINDOW=6` e `STRIDE=3`.

## Informações do Arquivo

| Campo         | Valor                       |
|---------------|-----------------------------|
| Autor         | Valmir F. Silva             |
| Contato       | valmir.silva@ee.ufcg.edu.br |
| Organização   | UFCG                        |
| Versão        | 2.0                         |
| Criado em     | 05/03/2026                  |